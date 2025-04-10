// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../LPtoken/AEthLPToken.sol"; // 修改为 AEthLPToken

contract AEthSwap is Ownable {
    IERC20 public tokenA; // 改为 A
    IERC20 public ETH; // 改为 ETH
    AEthLPToken public lpToken; // 修改为 AEthLPToken

    uint256 public priceCurrent;
    
    uint256 public reserveA; // 改为 reserveA
    uint256 public reserveETH; // 改为 reserveETH
    uint256 public totalLiquidity;
    uint256 public constant FEE_RATE = 25; // 0.25% 交易费
    uint256 public constant A = 100; // 放大系数 A（与代币 A 无关，保留原名称）

    // 监听事件
    event SwapExecuted(
        uint256 timestamp,
        uint256 priceCurrent,
        bool isAToETH, // 改为 isAToETH
        uint256 reserveA, // 改为 reserveA
        uint256 reserveETH, // 改为 reserveETH
        uint256 amountIn,
        uint256 amountOut
    );

    event SwapDetailed(
        uint256 feeAmount,
        uint256 amountAfterFee,
        uint256 new_x,
        uint256 new_y,
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 priceImpact
    );

    constructor(address _tokenA, address _ETH, address _lpToken) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        ETH = IERC20(_ETH);
        lpToken = AEthLPToken(_lpToken); // 修改为 AEthLPToken
    }

    /** @dev 添加流动性 */
    function addLiquidity(uint256 amountA, uint256 amountETH) external {
        require(amountA > 0 && amountETH > 0, "Amounts must be greater than zero");

        // 把代币转入池子
        tokenA.transferFrom(msg.sender, address(this), amountA);
        ETH.transferFrom(msg.sender, address(this), amountETH);

        uint256 lpAmount;
        if (totalLiquidity == 0) {
            lpAmount = (amountA + amountETH) / 2;
            priceCurrent = amountA / amountETH;
        } else {
            lpAmount = (amountA * totalLiquidity) / reserveA;
        }

        lpToken.mint(msg.sender, lpAmount);
        
        reserveA += amountA;
        reserveETH += amountETH;
        totalLiquidity += lpAmount;
    }

    /** @dev 取出流动性 */
    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "Invalid LP amount");

        uint256 amountA = (reserveA * lpAmount) / totalLiquidity;
        uint256 amountETH = (reserveETH * lpAmount) / totalLiquidity;

        lpToken.burn(msg.sender, lpAmount);
        tokenA.transfer(msg.sender, amountA);
        ETH.transfer(msg.sender, amountETH);

        reserveA -= amountA;
        reserveETH -= amountETH;
        totalLiquidity -= lpAmount;
        priceCurrent = amountA / amountETH;
    }

    /** @dev 计算交易详情 */
    function getSwapDetails(uint256 amountIn, bool isAToETH) 
        public
        returns (uint256 feeAmount, uint256 estimatedAmountOut, uint256 priceImpact) 
    {
        require(amountIn > 0, "Amount must be greater than zero");

        uint256 x = isAToETH ? reserveA : reserveETH;
        uint256 y = isAToETH ? reserveETH : reserveA;
        
        // 计算手续费
        feeAmount = (amountIn * FEE_RATE) / 10000;
        uint256 amountAfterFee = amountIn - feeAmount;

        // 计算估计的兑换数量
        uint256 new_x = x + amountAfterFee;
        uint256 new_y = (A * y * x) / (A * x + new_x);
        estimatedAmountOut = y - new_y;

        // 计算价格影响
        uint256 priceBefore = y * 1e18 / x; // 交易前的价格
        uint256 priceAfter = new_y * 1e18 / new_x; // 交易后的价格
        priceImpact = ((priceBefore - priceAfter) * 100) / priceBefore; // 百分比
        emit SwapDetailed(feeAmount, amountAfterFee, new_x, new_y, priceBefore, priceAfter, priceImpact);
    }

    /** @dev 兑换稳定币，支持滑点保护 */
    function swap(uint256 amountIn, bool isAToETH, uint256 minAmountOut) external {
        require(amountIn > 0, "Amount must be greater than zero");

        (, uint256 amountOut, ) = getSwapDetails(amountIn, isAToETH);
        require(amountOut >= minAmountOut, "Slippage exceeded"); // 滑点保护

        if (isAToETH) {
            tokenA.transferFrom(msg.sender, address(this), amountIn);
            ETH.transfer(msg.sender, amountOut);
            reserveA += amountIn;
            reserveETH -= amountOut;
        } else {
            ETH.transferFrom(msg.sender, address(this), amountIn);
            tokenA.transfer(msg.sender, amountOut);
            reserveETH += amountIn;
            reserveA -= amountOut;
        }

        // 手续费留在池子里
        uint256 fee = (amountIn * FEE_RATE) / 10000;
        if (isAToETH) {
            reserveA += fee;
        } else {
            reserveETH += fee;
        }
        priceCurrent = reserveA / reserveETH;

        emit SwapExecuted(block.timestamp, priceCurrent, isAToETH, reserveA, reserveETH, amountIn, amountOut);
    }

    /** @dev 根据输入的代币数量计算对应的另一方代币数量以保持池子比例 */
    function getPairedAmount(uint256 amountIn, bool isA) 
        public 
        view 
        returns (uint256 pairedAmount) 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        require(totalLiquidity > 0, "Pool is empty, no ratio available");

        if (totalLiquidity == 0) {
            return 0; 
        }

        if (isA) {
            pairedAmount = (amountIn * reserveETH) / reserveA;
        } else {
            pairedAmount = (amountIn * reserveA) / reserveETH;
        }
    }

    function getReservesAndLiquidity() public view 
        returns (uint256 reserveA_, uint256 reserveETH_, uint256 totalLiquidity_, uint256 priceCurrent_) 
    {
        reserveA_ = reserveA;
        reserveETH_ = reserveETH;
        totalLiquidity_ = totalLiquidity;
        priceCurrent_ = priceCurrent;
    }
}
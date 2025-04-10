// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../LPtoken/BEthLPToken.sol"; // 修改为 BEthLPToken

contract BEthSwap is Ownable { // 修改为 BEthSwap
    IERC20 public tokenB; // 改为 tokenB
    IERC20 public ETH;
    BEthLPToken public lpToken; // 修改为 BEthLPToken

    uint256 public priceCurrent;
    
    uint256 public reserveB; // 改为 reserveB
    uint256 public reserveETH;
    uint256 public totalLiquidity;
    uint256 public constant FEE_RATE = 25; // 0.25% 交易费
    uint256 public constant A = 100; // 放大系数 A，保留原名称

    // 监听事件
    event SwapExecuted(
        uint256 timestamp,
        uint256 priceCurrent,
        bool isBToETH, // 改为 isBToETH
        uint256 reserveB, // 改为 reserveB
        uint256 reserveETH,
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

    constructor(address _tokenB, address _ETH, address _lpToken) Ownable(msg.sender) {
        tokenB = IERC20(_tokenB); // 改为 tokenB
        ETH = IERC20(_ETH);
        lpToken = BEthLPToken(_lpToken); // 修改为 BEthLPToken
    }

    /** @dev 添加流动性 */
    function addLiquidity(uint256 amountB, uint256 amountETH) external {
        require(amountB > 0 && amountETH > 0, "Amounts must be greater than zero");

        // 把代币转入池子
        tokenB.transferFrom(msg.sender, address(this), amountB); // 改为 tokenB
        ETH.transferFrom(msg.sender, address(this), amountETH);

        uint256 lpAmount;
        if (totalLiquidity == 0) {
            lpAmount = (amountB + amountETH) / 2;
            priceCurrent = amountB / amountETH;
        } else {
            lpAmount = (amountB * totalLiquidity) / reserveB; // 改为 reserveB
        }

        lpToken.mint(msg.sender, lpAmount);
        
        reserveB += amountB; // 改为 reserveB
        reserveETH += amountETH;
        totalLiquidity += lpAmount;
    }

    /** @dev 取出流动性 */
    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "Invalid LP amount");

        uint256 amountB = (reserveB * lpAmount) / totalLiquidity; // 改为 amountB, reserveB
        uint256 amountETH = (reserveETH * lpAmount) / totalLiquidity;

        lpToken.burn(msg.sender, lpAmount);
        tokenB.transfer(msg.sender, amountB); // 改为 tokenB
        ETH.transfer(msg.sender, amountETH);

        reserveB -= amountB; // 改为 reserveB
        reserveETH -= amountETH;
        totalLiquidity -= lpAmount;
        priceCurrent = amountB / amountETH;
    }

    /** @dev 计算交易详情 */
    function getSwapDetails(uint256 amountIn, bool isBToETH) 
        public
        returns (uint256 feeAmount, uint256 estimatedAmountOut, uint256 priceImpact) 
    {
        require(amountIn > 0, "Amount must be greater than zero");

        uint256 x = isBToETH ? reserveB : reserveETH; // 改为 reserveB
        uint256 y = isBToETH ? reserveETH : reserveB; // 改为 reserveB
        
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
    function swap(uint256 amountIn, bool isBToETH, uint256 minAmountOut) external {
        require(amountIn > 0, "Amount must be greater than zero");

        (, uint256 amountOut, ) = getSwapDetails(amountIn, isBToETH);
        require(amountOut >= minAmountOut, "Slippage exceeded"); // 滑点保护

        if (isBToETH) {
            tokenB.transferFrom(msg.sender, address(this), amountIn); // 改为 tokenB
            ETH.transfer(msg.sender, amountOut);
            reserveB += amountIn; // 改为 reserveB
            reserveETH -= amountOut;
        } else {
            ETH.transferFrom(msg.sender, address(this), amountIn);
            tokenB.transfer(msg.sender, amountOut); // 改为 tokenB
            reserveETH += amountIn;
            reserveB -= amountOut; // 改为 reserveB
        }

        // 手续费留在池子里
        uint256 fee = (amountIn * FEE_RATE) / 10000;
        if (isBToETH) {
            reserveB += fee; // 改为 reserveB
        } else {
            reserveETH += fee;
        }
        priceCurrent = reserveB / reserveETH;

        emit SwapExecuted(block.timestamp, priceCurrent, isBToETH, reserveB, reserveETH, amountIn, amountOut); // 改为 isBToETH, reserveB
    }

    /** @dev 根据输入的代币数量计算对应的另一方代币数量以保持池子比例 */
    function getPairedAmount(uint256 amountIn, bool isB) 
        public 
        view 
        returns (uint256 pairedAmount) 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        require(totalLiquidity > 0, "Pool is empty, no ratio available");

        if (totalLiquidity == 0) {
            return 0; 
        }

        if (isB) {
            pairedAmount = (amountIn * reserveETH) / reserveB; // 改为 reserveB
        } else {
            pairedAmount = (amountIn * reserveB) / reserveETH; // 改为 reserveB
        }
    }

    function getReservesAndLiquidity() public view 
        returns (uint256 reserveB_, uint256 reserveETH_, uint256 totalLiquidity_, uint256 priceCurrent_) 
    {
        reserveB_ = reserveB; // 改为 reserveB_
        reserveETH_ = reserveETH;
        totalLiquidity_ = totalLiquidity;
        priceCurrent_ = priceCurrent;
    }
}
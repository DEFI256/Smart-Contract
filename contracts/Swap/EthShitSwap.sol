// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../LPtoken/EthShitLPToken.sol"; // 修改为 EthShitLPToken

contract EthShitSwap is Ownable {
    IERC20 public ETH;
    IERC20 public Shit;
    EthShitLPToken public lpToken; // 修改为 EthShitLPToken

    uint256 public priceCurrent;
    
    uint256 public reserveETH;
    uint256 public reserveShit;
    uint256 public totalLiquidity;
    uint256 public constant FEE_RATE = 25; // 0.25% 交易费
    uint256 public constant A = 100; // 放大系数 A

    // 监听事件
    event SwapExecuted(
        uint256 timestamp,
        uint256 priceCurrent,
        bool isETHToShit,
        uint256 reserveETH,
        uint256 reserveShit,
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

    constructor(address _ETH, address _Shit, address _lpToken) Ownable(msg.sender) {
        ETH = IERC20(_ETH);
        Shit = IERC20(_Shit);
        lpToken = EthShitLPToken(_lpToken); // 修改为 EthShitLPToken
    }

    /** @dev 添加流动性 */
    function addLiquidity(uint256 amountETH, uint256 amountShit) external {
        require(amountETH > 0 && amountShit > 0, "Amounts must be greater than zero");

        // 把代币转入池子
        ETH.transferFrom(msg.sender, address(this), amountETH);
        Shit.transferFrom(msg.sender, address(this), amountShit);

        uint256 lpAmount;
        if (totalLiquidity == 0) {
            lpAmount = (amountETH + amountShit) / 2;
            priceCurrent = amountETH / amountShit;
        } else {
            lpAmount = (amountETH * totalLiquidity) / reserveETH;
        }

        lpToken.mint(msg.sender, lpAmount);
        
        reserveETH += amountETH;
        reserveShit += amountShit;
        totalLiquidity += lpAmount;
    }

    /** @dev 取出流动性 */
    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "Invalid LP amount");

        uint256 amountETH = (reserveETH * lpAmount) / totalLiquidity;
        uint256 amountShit = (reserveShit * lpAmount) / totalLiquidity;

        lpToken.burn(msg.sender, lpAmount);
        ETH.transfer(msg.sender, amountETH);
        Shit.transfer(msg.sender, amountShit);

        reserveETH -= amountETH;
        reserveShit -= amountShit;
        totalLiquidity -= lpAmount;
        priceCurrent = amountETH / amountShit;
    }

    /** @dev 计算交易详情 */
    function getSwapDetails(uint256 amountIn, bool isETHToShit) 
        public
        returns (uint256 feeAmount, uint256 estimatedAmountOut, uint256 priceImpact) 
    {
        require(amountIn > 0, "Amount must be greater than zero");

        uint256 x = isETHToShit ? reserveETH : reserveShit;
        uint256 y = isETHToShit ? reserveShit : reserveETH;
        
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
    function swap(uint256 amountIn, bool isETHToShit, uint256 minAmountOut) external {
        require(amountIn > 0, "Amount must be greater than zero");

        (, uint256 amountOut, ) = getSwapDetails(amountIn, isETHToShit);
        require(amountOut >= minAmountOut, "Slippage exceeded"); // 滑点保护

        if (isETHToShit) {
            ETH.transferFrom(msg.sender, address(this), amountIn);
            Shit.transfer(msg.sender, amountOut);
            reserveETH += amountIn;
            reserveShit -= amountOut;
        } else {
            Shit.transferFrom(msg.sender, address(this), amountIn);
            ETH.transfer(msg.sender, amountOut);
            reserveShit += amountIn;
            reserveETH -= amountOut;
        }

        // 手续费留在池子里
        uint256 fee = (amountIn * FEE_RATE) / 10000;
        if (isETHToShit) {
            reserveETH += fee;
        } else {
            reserveShit += fee;
        }
        priceCurrent = reserveETH / reserveShit;

        emit SwapExecuted(block.timestamp, priceCurrent, isETHToShit, reserveETH, reserveShit, amountIn, amountOut);
    }

    /** @dev 根据输入的代币数量计算对应的另一方代币数量以保持池子比例 */
    function getPairedAmount(uint256 amountIn, bool isETH) 
        public 
        view 
        returns (uint256 pairedAmount) 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        require(totalLiquidity > 0, "Pool is empty, no ratio available");

        if (totalLiquidity == 0) {
            return 0; 
        }

        if (isETH) {
            pairedAmount = (amountIn * reserveShit) / reserveETH;
        } else {
            pairedAmount = (amountIn * reserveETH) / reserveShit;
        }
    }

    function getReservesAndLiquidity() public view 
        returns (uint256 reserveETH_, uint256 reserveShit_, uint256 totalLiquidity_, uint256 priceCurrent_) 
    {
        reserveETH_ = reserveETH;
        reserveShit_ = reserveShit;
        totalLiquidity_ = totalLiquidity;
        priceCurrent_ = priceCurrent;
    }
}
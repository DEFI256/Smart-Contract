// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LPToken.sol";

contract StableSwapPool is Ownable {
    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;
    
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    uint256 public constant FEE_RATE = 25; // 0.25% 交易费
    uint256 public constant A = 100; // 放大系数 A

    constructor(address _tokenA, address _tokenB, address _lpToken) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = LPToken(_lpToken);
    }

    /** @dev 添加流动性 */
    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");

        // 把代币转入池子
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 lpAmount;
        if (totalLiquidity == 0) {
            lpAmount = (amountA + amountB) / 2;
        } else {
            lpAmount = (amountA * totalLiquidity) / reserveA;
        }

        lpToken.mint(msg.sender, lpAmount);
        
        reserveA += amountA;
        reserveB += amountB;
        totalLiquidity += lpAmount;
    }

    /** @dev 取出流动性 */
    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "Invalid LP amount");

        uint256 amountA = (reserveA * lpAmount) / totalLiquidity;
        uint256 amountB = (reserveB * lpAmount) / totalLiquidity;

        lpToken.burn(msg.sender, lpAmount);
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        reserveA -= amountA;
        reserveB -= amountB;
        totalLiquidity -= lpAmount;
    }

    /** @dev 计算交易详情 */
    function getSwapDetails(uint256 amountIn, bool isAToB) 
        public 
        view 
        returns (uint256 feeAmount, uint256 estimatedAmountOut, uint256 priceImpact) 
    {
        require(amountIn > 0, "Amount must be greater than zero");

        uint256 x = isAToB ? reserveA : reserveB;
        uint256 y = isAToB ? reserveB : reserveA;
        
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
    }

    /** @dev 兑换稳定币，支持滑点保护 */
    function swap(uint256 amountIn, bool isAToB, uint256 minAmountOut) external {
        require(amountIn > 0, "Amount must be greater than zero");

        (, uint256 amountOut, ) = getSwapDetails(amountIn, isAToB);
        require(amountOut >= minAmountOut, "Slippage exceeded"); // 滑点保护

        if (isAToB) {
            tokenA.transferFrom(msg.sender, address(this), amountIn);
            tokenB.transfer(msg.sender, amountOut);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            tokenB.transferFrom(msg.sender, address(this), amountIn);
            tokenA.transfer(msg.sender, amountOut);
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // 手续费留在池子里
        uint256 fee = (amountIn * FEE_RATE) / 10000;
        if (isAToB) {
            reserveA += fee;
        } else {
            reserveB += fee;
        }
    }
}

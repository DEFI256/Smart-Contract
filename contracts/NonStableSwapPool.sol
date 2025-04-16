// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NonStableSwapPool is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public priceCurrent;
    
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    uint256 public constant FEE_RATE = 25; // 0.25% 交易费
    bool public paused = false;

    // 事件定义（保持不变）
    event LiquidityAdded(
        address indexed provider, 
        uint256 amountA, 
        uint256 amountB, 
        uint256 indexed lpAmount
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA, 
        uint256 amountB, 
        uint256 indexed lpAmount
    );

    event SwapExecuted(
        uint256 timestamp,
        uint256 priceCurrent,
        bool indexed isAToB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountIn,
        uint256 amountOut
    );

    event SwapDetailed(
        uint256 timestamp,
        address indexed user,
        uint256 feeAmount,
        uint256 amountAfterFee,
        uint256 priceImpact
    );

    event AmplificationCoefficientUpdated(
        uint256 oldValue,
        uint256 newValue
    );

    // 重入锁
    uint256 private locked = 1;

    modifier nonReentrant() {
        require(locked == 1, "Reentrant call");
        locked = 2;
        _;
        locked = 1;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(address _tokenA, address _tokenB, address _lpToken) Ownable(msg.sender) {
        require(_tokenA != address(0), "Token A cannot be zero address");
        require(_tokenB != address(0), "Token B cannot be zero address");
        require(_lpToken != address(0), "LP token cannot be zero address");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = LPToken(_lpToken);
    }

    // 牛顿迭代法计算平方根（保持不变）
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /**
     * @dev 计算交易详情，基于新公式 x^(1/2) * y = k
     */
    function getSwapDetails(uint256 amountIn, bool isAToB) 
        public 
        view 
        returns (uint256 feeAmount, uint256 estimatedAmountOut, uint256 priceImpact) 
    {
        require(amountIn > 0, "Amount must be greater than zero");

        uint256 x = isAToB ? reserveA : reserveB;
        uint256 y = isAToB ? reserveB : reserveA;
        
        if (x == 0 || y == 0) return (0, 0, 0);

        // 计算手续费
        feeAmount = (amountIn * FEE_RATE) / 10000;
        uint256 amountAfterFee = amountIn - feeAmount;

        // 计算估计的兑换数量
        if (isAToB) {
            // A 换 B：x * y^2 = k
            uint256 k = x * y * y; // x * y^2
            uint256 new_x = x + amountAfterFee;
            uint256 new_y = sqrt(k / new_x); // new_y^2 = k / new_x
            estimatedAmountOut = y - new_y;
        } else {
            // B 换 A：y * x^2 = k（对调 x 和 y）
            uint256 k = y * x * x; // y * x^2
            uint256 new_x = x + amountAfterFee;
            uint256 new_y = k /(new_x * new_x); // new_x^2 = k / new_y
            estimatedAmountOut = y - new_y;
        }

        // 计算价格影响
        uint256 priceBefore;
        uint256 priceAfter;
        if (isAToB) {
            priceBefore = (y * PRECISION) / x; // B/A
            uint256 new_x = x + amountAfterFee;
            uint256 new_y = sqrt((x * y * y) / new_x);
            priceAfter = (new_y * PRECISION) / new_x;
        } else {
            priceBefore = (y * PRECISION)/x ; // A/B
            uint256 new_x = x + amountAfterFee;
            uint256 new_y = (y * x * x) / (new_x*new_x);
            priceAfter = (new_y * PRECISION) / new_x;
        }
        
        // 避免负数价格影响
        if (priceAfter >= priceBefore) {
            priceImpact = 0;
        } else {
            priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore; // 使用基点
        }
    }

    /** 
     * @dev 添加流动性（保持不变，但更新价格逻辑）
     */
    function addLiquidity(
        uint256 amountA, 
        uint256 amountB, 
        uint256 minLpAmount
    ) external nonReentrant whenNotPaused {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");
        
        uint256 lpAmount;
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        uint256 _totalLiquidity = totalLiquidity;
        
        if (_totalLiquidity == 0) {
            lpAmount = (amountA + amountB) / 2;
            reserveA = amountA;
            reserveB = amountB;
            totalLiquidity = lpAmount;
            priceCurrent = (amountA * PRECISION) / amountB;
        } else {
            uint256 expectedAmountB = (amountA * _reserveB) / _reserveA;
            uint256 allowedDeviation = expectedAmountB / 100;
            require(
                amountB >= expectedAmountB - allowedDeviation && 
                amountB <= expectedAmountB + allowedDeviation,
                "Token ratio does not match pool ratio"
            );
            lpAmount = (amountA * _totalLiquidity) / _reserveA;
            reserveA = _reserveA + amountA;
            reserveB = _reserveB + amountB;
            totalLiquidity = _totalLiquidity + lpAmount;
            priceCurrent = (reserveA * PRECISION) / reserveB;
        }
        
        require(lpAmount >= minLpAmount, "LP amount below minimum");
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);
        lpToken.mint(msg.sender, lpAmount);
        
        emit LiquidityAdded(msg.sender, amountA, amountB, lpAmount);
    }

    /** 
     * @dev 移除流动性（保持不变，但更新价格逻辑）
     */
    function removeLiquidity(
        uint256 lpAmount, 
        uint256 minAmountA, 
        uint256 minAmountB
    ) external nonReentrant whenNotPaused {
        uint256 userLpBalance = lpToken.balanceOf(msg.sender);
        if (lpAmount == 0) {
            lpAmount = userLpBalance;
        }
        require(lpAmount > 0 && lpAmount <= userLpBalance, "Invalid LP amount");
        
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        uint256 _totalLiquidity = totalLiquidity;
        
        uint256 amountA = (_reserveA * lpAmount) / _totalLiquidity;
        uint256 amountB = (_reserveB * lpAmount) / _totalLiquidity;
        
        require(amountA >= minAmountA, "TokenA amount below minimum");
        require(amountB >= minAmountB, "TokenB amount below minimum");
        
        reserveA = _reserveA - amountA;
        reserveB = _reserveB - amountB;
        totalLiquidity = _totalLiquidity - lpAmount;
        
        priceCurrent = reserveB > 0 ? (reserveA * PRECISION) / reserveB : 0;
        
        lpToken.burn(msg.sender, lpAmount);
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    /** 
     * @dev 兑换代币，基于 x * y^2 = k
     */
    function swap(uint256 amountIn, bool isAToB, uint256 minAmountOut) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        
        (uint256 feeAmount, uint256 amountOutFinal, uint256 priceImpact) = getSwapDetails(amountIn, isAToB);
        
        require(amountOutFinal >= minAmountOut, "Slippage exceeded");
        
        if (isAToB) {
            require(_reserveB >= amountOutFinal, "Insufficient liquidity for B");
            reserveA = _reserveA + amountIn;
            reserveB = _reserveB - amountOutFinal;
            reserveA = reserveA + feeAmount; // 手续费归池子
            tokenA.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenB.safeTransfer(msg.sender, amountOutFinal);
        } else {
            require(_reserveA >= amountOutFinal, "Insufficient liquidity for A");
            reserveB = _reserveB + amountIn;
            reserveA = _reserveA - amountOutFinal;
            reserveB = reserveB + feeAmount; // 手续费归池子
            tokenB.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenA.safeTransfer(msg.sender, amountOutFinal);
        }

        priceCurrent = reserveB > 0 ? (reserveA * PRECISION) / reserveB : 0;

        emit SwapExecuted(
            block.timestamp, 
            priceCurrent, 
            isAToB, 
            reserveA, 
            reserveB, 
            amountIn, 
            amountOutFinal
        );
        
        emit SwapDetailed(
            block.timestamp,
            msg.sender,
            feeAmount,
            amountOutFinal,
            priceImpact
        );
    }

    /** 
     * @dev 获取另一方代币数量（保持不变）
     */
    function getPairedAmount(uint256 amountIn, bool isA) 
        public 
        view 
        returns (uint256 pairedAmount) 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        require(totalLiquidity > 0, "Pool is empty, no ratio available");

        if (isA) {
            pairedAmount = (amountIn * reserveB) / reserveA;
        } else {
            pairedAmount = (amountIn * reserveA) / reserveB;
        }
    }

    /**
     * @dev 获取池子信息（保持不变）
     */
    function getReservesAndLiquidity() public view 
        returns (uint256 reserveA_, uint256 reserveB_, uint256 totalLiquidity_, uint256 priceCurrent_) 
    {
        reserveA_ = reserveA;
        reserveB_ = reserveB;
        totalLiquidity_ = totalLiquidity;
        priceCurrent_ = priceCurrent;
    }

    /**
     * @dev 应急提款（保持不变）
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(paused, "Contract must be paused first");
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @dev 暂停和恢复（保持不变）
     */
    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StableSwapPool is Ownable {
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
    uint256 public amplificationCoefficient = 100; // Curve的放大系数 A，可调整
    bool public paused = false;

    // 添加更多索引
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

    /**
     * @dev Curve稳定币池的不变量计算函数 D
     * 解方程：A * n^n * sum(x_i) + D = A * D * n^n + D^(n+1) / (n^n * prod(x_i))
     * 对于两个代币，n = 2
     */
    function getD(uint256 _x, uint256 _y) public view returns (uint256) {
        uint256 ampCoeff = amplificationCoefficient;
        uint256 sum = _x + _y;
        if (sum == 0) return 0;
        
        uint256 d = sum;
        uint256 d_prev;
        // A * n * n, 其中 n = 2
        uint256 ann = ampCoeff * 2 * 2; 
        
        // 牛顿迭代法求解 D
        for (uint256 i = 0; i < 32; i++) {
            uint256 d_prod = d;
            // 优化计算，改善精度
            d_prod = (d_prod * d) / (_x * 2);
            d_prod = (d_prod * d) / (_y * 2);
            d_prev = d;
            
            // 修正括号以确保正确的计算顺序
            d = ((ann * sum) + (d_prod * 2)) * d / ((ann - 1) * d + (3 * d_prod));
            
            // 收敛条件：差值小于0.00001%
            if (d > d_prev) {
                if (d - d_prev <= 1) break;
            } else {
                if (d_prev - d <= 1) break;
            }
        }
        
        return d;
    }

    /**
     * @dev 计算稳定币交换的输出数量
     * 基于Curve的稳定币交换公式
     */
    function getYForX(uint256 x, uint256 y, uint256 x_new) public view returns (uint256) {
        uint256 d = getD(x, y);
        uint256 ampCoeff = amplificationCoefficient;
        // A * n * n, 其中 n = 2
        uint256 ann = ampCoeff * 2 * 2; 
        
        // 优化计算，避免精度损失
        uint256 c = (d * d) / (x_new * 2);
        c = (c * d) / (ann * 2);
        
        uint256 b = x_new + (d / ann);
        uint256 y_new;
        
        // 牛顿迭代法求解 y_new
        y_new = d;
        for (uint256 i = 0; i < 32; i++) {
            uint256 y_prev = y_new;
            // 优化计算精度
            y_new = ((y_new * y_new) + c) / ((y_new * 2) + b - d);
            
            // 收敛条件
            if (y_new > y_prev) {
                if (y_new - y_prev <= 1) break;
            } else {
                if (y_prev - y_new <= 1) break;
            }
        }
        
        return y_new;
    }

    /** 
     * @dev 添加流动性
     * 添加A和B两种稳定币到流动性池，包含滑点保护
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
        
        // A. 计算LP代币数量和更新状态变量
        if (_totalLiquidity == 0) {
            // 首次添加流动性
            uint256 d = getD(amountA, amountB);
            lpAmount = d;
            
            // 更新状态变量
            reserveA = amountA;
            reserveB = amountB;
            totalLiquidity = lpAmount;
            
            // 更新价格 - 使用精度因子避免精度损失
            if (amountB > 0) {
                priceCurrent = (amountA * PRECISION) / amountB;
            }
        } else {
            // 已有流动性，检查比例
            uint256 expectedAmountB = (amountA * _reserveB) / _reserveA;
            uint256 allowedDeviation = expectedAmountB / 100; // 1%的误差
            
            require(
                amountB >= expectedAmountB - allowedDeviation && 
                amountB <= expectedAmountB + allowedDeviation,
                "Token ratio does not match pool ratio"
            );
            
            // 计算新的不变量D
            uint256 d_before = getD(_reserveA, _reserveB);
            uint256 d_after = getD(_reserveA + amountA, _reserveB + amountB);
            
            // 基于D的变化比例计算LP代币，提高计算精度
            lpAmount = (_totalLiquidity * (d_after - d_before)) / d_before;
            
            // 更新状态变量
            reserveA = _reserveA + amountA;
            reserveB = _reserveB + amountB;
            totalLiquidity = _totalLiquidity + lpAmount;
            
            // 更新价格
            if (reserveB > 0) {
                priceCurrent = (reserveA * PRECISION) / reserveB;
            }
        }
        
        // 滑点保护
        require(lpAmount >= minLpAmount, "LP amount below minimum");
        
        // B. 执行转账和铸造
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);
        lpToken.mint(msg.sender, lpAmount);
        
        emit LiquidityAdded(msg.sender, amountA, amountB, lpAmount);
    }

    /** 
     * @dev 移除部分或全部流动性
     * @param lpAmount 要移除的LP代币数量，0表示全部移除
     * @param minAmountA tokenA的最小返还量
     * @param minAmountB tokenB的最小返还量
     */
    function removeLiquidity(
        uint256 lpAmount, 
        uint256 minAmountA, 
        uint256 minAmountB
    ) external nonReentrant whenNotPaused {
        uint256 userLpBalance = lpToken.balanceOf(msg.sender);
        
        // 如果lpAmount为0，移除全部流动性
        if (lpAmount == 0) {
            lpAmount = userLpBalance;
        }
        
        require(lpAmount > 0 && lpAmount <= userLpBalance, "Invalid LP amount");
        
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        uint256 _totalLiquidity = totalLiquidity;
        
        // 计算用户可提取的代币数量
        uint256 amountA = (_reserveA * lpAmount) / _totalLiquidity;
        uint256 amountB = (_reserveB * lpAmount) / _totalLiquidity;
        
        // 滑点保护
        require(amountA >= minAmountA, "TokenA amount below minimum");
        require(amountB >= minAmountB, "TokenB amount below minimum");
        
        // 更新池子状态
        reserveA = _reserveA - amountA;
        reserveB = _reserveB - amountB;
        totalLiquidity = _totalLiquidity - lpAmount;
        
        // 更新价格
        if (reserveB > 0) {
            priceCurrent = (reserveA * PRECISION) / reserveB;
        } else {
            priceCurrent = 0;
        }
        
        // 燃烧用户的 LP 代币，并转移代币 A 和 B
        lpToken.burn(msg.sender, lpAmount);
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    /** 
     * @dev 预先查询兑换数量 
     * 返回手续费、预估输出数量和价格影响
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

        // 计算估计的兑换数量（不含手续费）
        uint256 x_new = x + amountIn;
        uint256 y_new = getYForX(x, y, x_new);
        uint256 amountOutRaw = y - y_new;  // 原始兑换数量

        // 基于 `amountOutRaw` 计算手续费，提高精度
        feeAmount = (amountOutRaw * FEE_RATE) / 10000;
        estimatedAmountOut = amountOutRaw - feeAmount;  // 最终用户收到的数量

        // 计算价格影响，提高精度
        uint256 priceBefore = (y * PRECISION) / x;  // 交易前的价格
        uint256 priceAfter = (y_new * PRECISION) / x_new;  // 交易后的价格
        
        // 避免负数价格影响
        if (priceAfter >= priceBefore) {
            priceImpact = 0;
        } else {
            // 使用10000(基点)作为百分比精度，避免小数
            priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore; 
        }
    }

    /** 
     * @dev 兑换稳定币，支持滑点保护
     */
    function swap(uint256 amountIn, bool isAToB, uint256 minAmountOut) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        
        // A. 计算输出金额
        (uint256 feeAmount, uint256 amountOutFinal, uint256 priceImpact) = getSwapDetails(amountIn, isAToB);
        
        // 滑点保护
        require(amountOutFinal >= minAmountOut, "Slippage exceeded");
        
        // B. 更新状态变量
        if (isAToB) {
            require(_reserveB >= amountOutFinal, "Insufficient liquidity for B");
            
            // 更新储备
            reserveA = _reserveA + amountIn;
            reserveB = _reserveB - amountOutFinal;
            
            // 手续费留在池子里（将手续费部分加回池子）
            reserveB = reserveB + feeAmount;
            
            // C. 执行转账
            tokenA.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenB.safeTransfer(msg.sender, amountOutFinal);
        } else {
            require(_reserveA >= amountOutFinal, "Insufficient liquidity for A");
            
            // 更新储备
            reserveB = _reserveB + amountIn;
            reserveA = _reserveA - amountOutFinal;
            
            // 手续费留在池子里
            reserveA = reserveA + feeAmount;
            
            // C. 执行转账
            tokenB.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenA.safeTransfer(msg.sender, amountOutFinal);
        }

        // 更新价格，提高精度
        if (reserveB > 0) {
            priceCurrent = (reserveA * PRECISION) / reserveB;
        } else {
            priceCurrent = 0;
        }

        // 发出详细的交换事件信息
        emit SwapExecuted(
            block.timestamp, 
            priceCurrent, 
            isAToB, 
            reserveA, 
            reserveB, 
            amountIn, 
            amountOutFinal
        );
        
        // 额外发出更详细的信息事件
        emit SwapDetailed(
            block.timestamp,
            msg.sender,
            feeAmount,
            amountOutFinal,
            priceImpact
        );
    }

    /** 
     * @dev 根据输入的代币数量计算对应的另一方代币数量以保持池子比例
     */
    function getPairedAmount(uint256 amountIn, bool isA) 
        public 
        view 
        returns (uint256 pairedAmount) 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        require(totalLiquidity > 0, "Pool is empty, no ratio available");

        if (isA) {
            // 提高计算精度
            pairedAmount = (amountIn * reserveB) / reserveA;
        } else {
            pairedAmount = (amountIn * reserveA) / reserveB;
        }
    }

    /**
     * @dev 获取池子的基本信息
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
     * @dev 添加应急提款功能 - 仅限管理员
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(paused, "Contract must be paused first");
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @dev 暂停合约
     */
    function pause() external onlyOwner {
        paused = true;
    }

    /**
     * @dev 恢复合约运行
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    /**
     * @dev 更新放大系数
     * 仅限所有者调用
     */
    function setAmplificationCoefficient(uint256 _newA) external onlyOwner {
        require(_newA >= 1 && _newA <= 1000000, "A out of range");
        
        emit AmplificationCoefficientUpdated(amplificationCoefficient, _newA);
        amplificationCoefficient = _newA;
    }
}
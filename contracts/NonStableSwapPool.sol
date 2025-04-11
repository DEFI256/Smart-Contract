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
    uint256 public amplificationCoefficient = 100; // 放大系数，初始值为 100，可动态调整
    bool public paused = false;

    // 事件定义
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

    // 构造函数
    constructor(address _tokenA, address _tokenB, address _lpToken) Ownable(msg.sender) {
        require(_tokenA != address(0), "Token A cannot be zero address");
        require(_tokenB != address(0), "Token B cannot be zero address");
        require(_lpToken != address(0), "LP token cannot be zero address");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = LPToken(_lpToken);
    }

    /**
     * @dev 计算交易详情，基于 AEthSwap 的 AMM 算法
     * 使用公式：new_y = (amplificationCoefficient * y * x) / (amplificationCoefficient * x + new_x)
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
        uint256 new_x = x + amountAfterFee;
        uint256 new_y = (amplificationCoefficient * y * x) / (amplificationCoefficient * x + new_x);
        estimatedAmountOut = y - new_y;

        // 计算价格影响
        uint256 priceBefore = (y * PRECISION) / x; // 交易前的价格
        uint256 priceAfter = (new_y * PRECISION) / new_x; // 交易后的价格
        
        // 避免负数价格影响
        if (priceAfter >= priceBefore) {
            priceImpact = 0;
        } else {
            priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore; // 使用基点
        }
    }

    /** 
     * @dev 添加流动性
     * 包含滑点保护，基于池子比例分配 LP 代币
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
        
        // 计算 LP 代币数量和更新状态变量
        if (_totalLiquidity == 0) {
            // 首次添加流动性
            lpAmount = (amountA + amountB) / 2;
            
            // 更新状态变量
            reserveA = amountA;
            reserveB = amountB;
            totalLiquidity = lpAmount;
            
            // 更新价格
            if (amountB > 0) {
                priceCurrent = (amountA * PRECISION) / amountB;
            }
        } else {
            // 已有流动性，检查比例
            uint256 expectedAmountB = (amountA * _reserveB) / _reserveA;
            uint256 allowedDeviation = expectedAmountB / 100; // 1% 误差
            
            require(
                amountB >= expectedAmountB - allowedDeviation && 
                amountB <= expectedAmountB + allowedDeviation,
                "Token ratio does not match pool ratio"
            );
            
            // 按比例分配 LP 代币
            lpAmount = (amountA * _totalLiquidity) / _reserveA;
            
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
        
        // 执行转账和铸造
        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);
        lpToken.mint(msg.sender, lpAmount);
        
        emit LiquidityAdded(msg.sender, amountA, amountB, lpAmount);
    }

    /** 
     * @dev 移除部分或全部流动性
     */
    function removeLiquidity(
        uint256 lpAmount, 
        uint256 minAmountA, 
        uint256 minAmountB
    ) external nonReentrant whenNotPaused {
        uint256 userLpBalance = lpToken.balanceOf(msg.sender);
        
        // 如果 lpAmount 为 0，移除全部流动性
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
        
        // 燃烧 LP 代币并转移代币
        lpToken.burn(msg.sender, lpAmount);
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    /** 
     * @dev 兑换代币，支持滑点保护
     * 使用 AEthSwap 的 AMM 算法
     */
    function swap(uint256 amountIn, bool isAToB, uint256 minAmountOut) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        
        // 计算输出金额
        (uint256 feeAmount, uint256 amountOutFinal, uint256 priceImpact) = getSwapDetails(amountIn, isAToB);
        
        // 滑点保护
        require(amountOutFinal >= minAmountOut, "Slippage exceeded");
        
        // 更新状态变量并执行转账
        if (isAToB) {
            require(_reserveB >= amountOutFinal, "Insufficient liquidity for B");
            
            // 更新储备
            reserveA = _reserveA + amountIn;
            reserveB = _reserveB - amountOutFinal;
            
            // 手续费留在池子里
            reserveA = reserveA + feeAmount;
            
            // 执行转账
            tokenA.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenB.safeTransfer(msg.sender, amountOutFinal);
        } else {
            require(_reserveA >= amountOutFinal, "Insufficient liquidity for A");
            
            // 更新储备
            reserveB = _reserveB + amountIn;
            reserveA = _reserveA - amountOutFinal;
            
            // 手续费留在池子里
            reserveA = reserveA + feeAmount;
            
            // 执行转账
            tokenB.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenA.safeTransfer(msg.sender, amountOutFinal);
        }

        // 更新价格
        if (reserveB > 0) {
            priceCurrent = (reserveA * PRECISION) / reserveB;
        } else {
            priceCurrent = 0;
        }

        // 发出事件
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
     * @dev 应急提款功能，仅限管理员
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
        require(_newA >= 1 && _newA <= 1000000, "Amplification coefficient out of range");
        
        emit AmplificationCoefficientUpdated(amplificationCoefficient, _newA);
        amplificationCoefficient = _newA;
    }
}
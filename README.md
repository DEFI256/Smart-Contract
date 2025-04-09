# 初始化

###    1. 初始化 Hardhat 项目

### 1.1 创建项目目录并初始化

```
npm init -y
```

### 1.2 安装 Hardhat 和依赖

```
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npx hardhat init
```

### 1.3 项目结构

初始化后，项目目录如下：

```
my-token-project/
├── contracts/           # 存放智能合约（.sol 文件）
├── scripts/            # 部署脚本（如 deploy.ts）
├── test/               # 测试文件
├── hardhat.config.ts   # Hardhat 配置文件
└── package.json
```



### 2.2 安装 OpenZeppelin 合约库

```
npm install @openzeppelin/contracts
```



# **从这里开始** 

### **3. 执行部署**

#### **3.1 本地测试网络**

```
npx hardhat node
```

新终端窗口运行：

```
npx hardhat run scripts/deploy.js --network localhost
```





#  重启



要重启 Hardhat 环境（包括本地节点、缓存清理等），可以按照以下步骤操作：

------

### **1. 停止正在运行的 Hardhat 本地节点**

如果正在运行 `npx hardhat node`（本地开发链），直接：

- **在终端按 `Ctrl + C`** 终止进程。

------

### **2. 清理 Hardhat 缓存和旧编译文件**

Hardhat 会缓存编译结果和部署信息，清理它们可避免旧数据干扰：



```
npx hardhat clean
```

这会删除 `artifacts/` 和 `cache/` 目录。

------

### **3. 重新编译合约**

```
npx hardhat compile
```

确保合约代码是最新编译状态。

------

### **4. 重启本地节点（可选）**

如果需要本地测试链：

```
npx hardhat node
```

保持此终端运行，另开新终端执行部署或测试。







## **6. 与合约交互**

### 6.1 使用 Hardhat Console

```
npx hardhat console --network localhost
```

在交互式控制台中操作：



```
// 获取合约实例
const TokenA = await ethers.getContractFactory("TokenA");
const tokenA = TokenA.attach("0x5FbDB2315678afecb367f032d93F642f64180aa3");

// 查询代币名称
await tokenA.name(); // "TokenA"

// 转账给第二个测试账户
const [sender, receiver] = await ethers.getSigners();
await tokenA.transfer(receiver.address, ethers.parseUnits("100", 18));

// 查询接收者余额
await tokenA.balanceOf(receiver.address); // 返回 BigNumber
```

### 6.2 编写调用脚本（`scripts/interact.js`）



```
const { ethers } = require("hardhat");

async function main() {
  const tokenA = await ethers.getContractAt(
    "TokenA",
    "0x5FbDB2315678afecb367f032d93F642f64180aa3" // 替换为你的地址
  );

  const [account1, account2] = await ethers.getSigners();
  console.log(
    "Account 1 balance:",
    await tokenA.balanceOf(account1.address)
  );
}

main();
```



```
npx hardhat run scripts/interact.js --network localhost
```
















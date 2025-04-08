const { ethers } = require("hardhat");

async function main() {
    console.log("开始部署稳定币交换池和代币合约...");

    // 获取合约工厂
    const TokenA = await ethers.getContractFactory("Token_A");
    const TokenB = await ethers.getContractFactory("Token_B");
    const LPToken = await ethers.getContractFactory("LPToken");
    const StableSwapPool = await ethers.getContractFactory("StableSwapPool");

    // 部署代币合约 - 添加正确的构造函数参数
    const tokenA = await TokenA.deploy("Token A", "TA", 1000000);
    const tokenB = await TokenB.deploy("Token B", "TB", 1000000);
    
    console.log("Token A 部署成功:", await tokenA.getAddress());
    console.log("Token B 部署成功:", await tokenB.getAddress());

    // 部署LP代币合约
    const lpToken = await LPToken.deploy("LP Token", "LP");
    console.log("LP Token 部署成功:", await lpToken.getAddress());

    // 部署交换池合约
    const tokenAAddress = await tokenA.getAddress();
    const tokenBAddress = await tokenB.getAddress();
    const lpTokenAddress = await lpToken.getAddress();
    
    const pool = await StableSwapPool.deploy(tokenAAddress, tokenBAddress, lpTokenAddress);
    console.log("StableSwapPool 部署成功:", await pool.getAddress());

    // 设置LP代币的池子地址
    await lpToken.setPool(await pool.getAddress());
    console.log("LP代币已设置池子地址");
    
    console.log("所有合约部署完成!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("部署过程中出错:", error);
        process.exit(1);
    });
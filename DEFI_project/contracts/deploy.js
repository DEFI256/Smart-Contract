const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // 1. 部署 TokenA 和 TokenB
    const initialSupply = hre.ethers.utils.parseUnits("10000", 18);

    const Token_A = await hre.ethers.getContractFactory("Token_A");
    const token_A = await Token_A.deploy("A", "A", initialSupply);
    await token_A.deployed();
    console.log("Token_A deployed at:", token_A.address);

    const Token_B = await hre.ethers.getContractFactory("Token_B");
    const token_B = await Token_B.deploy("B", "B", initialSupply);
    await token_B.deployed();
    console.log("Token_B deployed at:", token_B.address);

    // 2. 部署 LPToken
    const LPToken = await hre.ethers.getContractFactory("LPToken");
    const lpToken = await LPToken.deploy("TP", "TP");
    await lpToken.deployed();
    console.log("LPToken deployed at:", lpToken.address);

    // 3. 部署 StableSwapPool
    const StableSwapPool = await hre.ethers.getContractFactory("StableSwapPool");
    const stableSwap = await StableSwapPool.deploy(tokenA.address, tokenB.address, lpToken.address);
    await stableSwap.deployed();
    console.log("StableSwapPool deployed at:", stableSwap.address);

    // 4. 绑定 LPToken 到 StableSwapPool
    await lpToken.setPool(stableSwap.address);
    console.log("LPToken pool set to StableSwapPool");

    // 5. 授权 StableSwapPool 操作 TokenA 和 TokenB
    await token_A.approve(stableSwap.address, initialSupply);
    await token_B.approve(stableSwap.address, initialSupply);
    console.log("Approved StableSwapPool for TokenA and TokenB");

    // 6. 添加流动性 5000/5000
    const liquidityAmount = hre.ethers.utils.parseUnits("5000", 18);
    await stableSwap.addLiquidity(liquidityAmount, liquidityAmount);
    console.log("Added initial liquidity: 5000 TokenA + 5000 TokenB");
}

// 运行部署脚本
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

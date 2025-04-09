const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // 1. 部署 TokenA 和 TokenB
    // const initialSupply = hre.ethers.utils.parseUnits("10000", 18);
    // As of ethers version 6 ethers.utils.parseUnit() has been replaced by ethers.parseUnit()
    const initialSupply = hre.ethers.parseUnits("10000", 18);   

    const Token_A = await hre.ethers.getContractFactory("Token_A");
    const token_A = await Token_A.deploy("A", "A", initialSupply);
    await token_A.waitForDeployment();
    const token_A_address = await token_A.getAddress();
    console.log("Token_A deployed at:", token_A_address);

    const Token_B = await hre.ethers.getContractFactory("Token_B");
    const token_B = await Token_B.deploy("B", "B", initialSupply);
    await token_B.waitForDeployment();
    const token_B_address = await token_B.getAddress();
    console.log("Token_B deployed at:", token_B_address);

    // console.log("Token_B deployed at:", token_B.getAddress);

    // 2. 部署 LPToken
    const LPToken = await hre.ethers.getContractFactory("LPToken");
    const lpToken = await LPToken.deploy("TP", "TP");
    await lpToken.waitForDeployment();
    const lpToken_address = await lpToken.getAddress();
    console.log("LPToken deployed at:", lpToken_address);

    // 3. 部署 StableSwapPool
    const StableSwapPool = await hre.ethers.getContractFactory("StableSwapPool");
    const stableSwap = await StableSwapPool.deploy(token_A_address, token_B_address, lpToken_address);
    await stableSwap.waitForDeployment();
    const stableSwap_address = await stableSwap.getAddress();
    console.log("StableSwapPool deployed at:", stableSwap_address);

    // 4. 绑定 LPToken 到 StableSwapPool
    await lpToken.setPool(stableSwap_address);
    console.log("LPToken pool set to StableSwapPool");

    // 5. 授权 StableSwapPool 操作 TokenA 和 TokenB
    await token_A.approve(stableSwap_address, initialSupply);
    await token_B.approve(stableSwap_address, initialSupply);
    console.log("Approved StableSwapPool for TokenA and TokenB");

    // 6. 添加流动性 5000/5000
    const liquidityAmount = hre.ethers.parseUnits("5000", 18);
    await stableSwap.addLiquidity(liquidityAmount, liquidityAmount,0);
    console.log("Added initial liquidity: 5000 TokenA + 5000 TokenB");
}

// 运行部署脚本
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

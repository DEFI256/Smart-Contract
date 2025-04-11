// const hre = require("hardhat");
// const fs = require("fs");
// const path = require("path");
// async function main() {
//     const [deployer] = await hre.ethers.getSigners();
//     console.log("Deploying contracts with the account:", deployer.address);

//     // 1. 部署 所有 token 
//     // const initialSupply = hre.ethers.utils.parseUnits("10000", 18);
//     // As of ethers version 6 ethers.utils.parseUnit() has been replaced by ethers.parseUnit()

//     const initialSupply = hre.ethers.parseUnits("1000", 18);   

//     const Token_USDT= await hre.ethers.getContractFactory("Token");
//     const token_USDT = await Token_USDT.deploy("Tether USD", "USDT", initialSupply);
//     await token_USDT.waitForDeployment();
//     const token_USDT_address = await token_USDT.getAddress();
//     console.log("token_USDT_address deployed at:", token_USDT_address);
    

//     const Token_DAI= await hre.ethers.getContractFactory("Token");
//     const token_DAI = await Token_DAI.deploy("Dai Stablecoin", "DAI", initialSupply);
//     await token_DAI.waitForDeployment();
//     const token_DAI_address = await token_DAI.getAddress();
//     console.log("token_DAI_address deployed at:", token_DAI_address);

//     const Token_wETH= await hre.ethers.getContractFactory("Token");
//     const token_wETH = await Token_wETH.deploy("Wrapped Ether", "wETH", initialSupply);
//     await token_wETH.waitForDeployment();
//     const token_wETH_address = await token_wETH.getAddress();
//     console.log("token_wETH_address deployed at:", token_wETH_address);

//     const Token_SHIT= await hre.ethers.getContractFactory("Token");
//     const token_SHIT = await Token_SHIT.deploy("shit coin", "SHIT", initialSupply);
//     await token_SHIT.waitForDeployment();
//     const token_SHIT_address = await token_SHIT.getAddress();
//     console.log("token_SHIT_address deployed at:", token_SHIT_address);

//     // console.log("Token_B deployed at:", token_B.getAddress);

//     // 2. 部署 LPToken
//     const LPToken = await hre.ethers.getContractFactory("LPToken");
//     const lpToken_1 = await LPToken.deploy("TP", "TP");
//     await lpToken_1.waitForDeployment();
//     const lpToken_address_1 = await lpToken_1.getAddress();
//     console.log("LPToken1 deployed at:", lpToken_address_1);
//     const deployLPToken = async (name, symbol) => {
//         const LPToken = await hre.ethers.getContractFactory("LPToken");
//         const lpToken = await LPToken.deploy(name, symbol);
//         await lpToken.waitForDeployment();
//         return lpToken;
//     };

//     const lpTokens = {
//         USDT_DAI: await deployLPToken("USDT_DAI_LP", "USDTDAI"),
//         USDT_wETH: await deployLPToken("USDT_wETH_LP", "USDTwETH"),
//         USDT_SHIT: await deployLPToken("USDT_SHIT_LP", "USDTSHIT"),
//         DAI_wETH: await deployLPToken("DAI_wETH_LP", "DAIwETH"),
//         SHIT_wETH: await deployLPToken("SHIT_wETH_LP", "SHITwETH"),
//     };

//     const lpTokenAddresses = {
//         USDT_DAI: await lpTokens.USDT_DAI.getAddress(),
//         USDT_wETH: await lpTokens.USDT_wETH.getAddress(),
//         USDT_SHIT: await lpTokens.USDT_SHIT.getAddress(),
//         DAI_wETH: await lpTokens.DAI_wETH.getAddress(),
//         SHIT_wETH: await lpTokens.SHIT_wETH.getAddress()
//     };

//     // const lpToken_2 = await LPToken.deploy("SHIT", "SHIT");
//     // await lpToken_2.waitForDeployment();
//     // const lpToken_address_2 = await lpToken_2.getAddress();
//     // console.log("LPToken2 deployed at:", lpToken_address_2);


//     // const lpToken_3 = await LPToken.deploy("wETH", "wETH");
//     // await lpToken_3.waitForDeployment();
//     // const lpToken_address_3 = await lpToken_3.getAddress();
//     // console.log("LPToken3 deployed at:", lpToken_address_3);


//     // const lpToken_4 = await LPToken.deploy("DAI", "DAI");
//     // await lpToken_4.waitForDeployment();
//     // const lpToken_address_4 = await lpToken_4.getAddress();
//     // console.log("LPToken4 deployed at:", lpToken_address_4);



//     // const lpToken_5 = await LPToken.deploy("USDT", "USDT");
//     // await lpToken_5.waitForDeployment();
//     // const lpToken_address_5 = await lpToken_5.getAddress();
//     // console.log("LPToken5 deployed at:", lpToken_address_5);

    
//     // const lpToken_6 = await LPToken.deploy("USDT", "USDT");
//     // await lpToken_6.waitForDeployment();
//     // const lpToken_address_6 = await lpToken_6.getAddress();
//     // console.log("LPToken6 deployed at:", lpToken_address_6);



//     // 3. 部署 StableSwapPool
//     const StableSwapPool = await hre.ethers.getContractFactory("StableSwapPool");
//     const USDT_DAI_SwapPool = await StableSwapPool.deploy(token_USDT_address, token_DAI_address, lpToken_address_1);
//     await USDT_DAI_SwapPool.waitForDeployment();
//     const USDT_DAI_SwapPool_address = await USDT_DAI_SwapPool.getAddress();
//     console.log("USDT_DAI_SwapPool deployed at:", USDT_DAI_SwapPool_address);

//     // 4. 绑定 LPToken 到 StableSwapPool
//     await lpToken_1.setPool(USDT_DAI_SwapPool_address);
//     console.log("LPToken_1 pool set to USDT_DAI_SwapPool");

//     // 5. 授权 StableSwapPool 操作 TokenA 和 TokenB
//     await token_USDT.approve(USDT_DAI_SwapPool_address, initialSupply);
//     await token_DAI.approve(USDT_DAI_SwapPool_address, initialSupply);
//     console.log("Approved USDT_DAI_SwapPool_address for token_USDT and token_DAI");

//     // 6. 添加流动性 
//     const liquidityAmount = hre.ethers.parseUnits("500", 18);
//     await USDT_DAI_SwapPool.addLiquidity(liquidityAmount, liquidityAmount,0);
//     console.log("Added initial liquidity: 5000 token_USDT + 5000 token_DAI");


//     // 3. 部署 其余SwapPool  USDT_wETH
//     const nonStableSwapPool = await hre.ethers.getContractFactory("NonStableSwapPool");
//     const USDT_wETH_SwapPool = await nonStableSwapPool.deploy(token_USDT_address, token_wETH_address, lpToken_address_2);
//     await USDT_wETH_SwapPool.waitForDeployment();
//     const USDT_wETH_SwapPool_address = await USDT_wETH_SwapPool.getAddress();
//     console.log("USDT_wETH_SwapPool deployed at:", USDT_wETH_SwapPool_address);

//     // 4. 绑定 LPToken 到 StableSwapPool
//     await lpToken_2.setPool(USDT_wETH_SwapPool_address);
//     console.log("LPToken_2 pool set to USDT_wETH_SwapPool");

//     // 5. 授权 StableSwapPool 操作 TokenA 和 TokenB
//     await token_USDT.approve(USDT_wETH_SwapPool_address, initialSupply);
//     await token_wETH.approve(USDT_wETH_SwapPool_address, initialSupply);
//     console.log("Approved USDT_wETH_SwapPool_address for token_USDT and token_wETH");

//     // 6. 添加流动性 
//     const x_1 = hre.ethers.parseUnits("100", 18);
//     await USDT_wETH_SwapPool.addLiquidity(liquidityAmount, liquidityAmount,0);
//     console.log("Added initial liquidity: 5000 token_USDT + 5000 token_wETH");
    

//      // **写入 JSON 文件**
//      const deploymentInfo = {
//         deployer: deployer.address,
//         token_USDT_address: token_USDT_address,
//         token_DAI_address: token_DAI_address,
//         LPToken_1: lpToken_address_1,
//         StableSwapPool: USDT_DAI_SwapPool_address
//     };

//     const filePath = path.join(__dirname, "deployed_contracts.json");
//     fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));

//     console.log("Deployment info saved to frontend/src/deployed_contracts.json");

// }

// // 运行部署脚本
// main()
//     .then(() => process.exit(0))
//     .catch((error) => {
//         console.error(error);
//         process.exit(1);
//     });


const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const initialSupply = hre.ethers.parseUnits("1000", 18);

    // 1. 部署代币
    const deployToken = async (name, symbol) => {
        const Token = await hre.ethers.getContractFactory("Token");
        const token = await Token.deploy(name, symbol, initialSupply);
        await token.waitForDeployment();
        return token;
    };

    const token_USDT = await deployToken("Tether USD", "USDT");
    const token_DAI = await deployToken("Dai Stablecoin", "DAI");
    const token_wETH = await deployToken("Wrapped Ether", "wETH");
    const token_SHIT = await deployToken("shit coin", "SHIT");

    const tokenAddresses = {
        USDT: await token_USDT.getAddress(),
        DAI: await token_DAI.getAddress(),
        wETH: await token_wETH.getAddress(),
        SHIT: await token_SHIT.getAddress()
    };

    // 2. 部署 LPToken
    const deployLPToken = async (name, symbol) => {
        const LPToken = await hre.ethers.getContractFactory("LPToken");
        const lpToken = await LPToken.deploy(name, symbol);
        await lpToken.waitForDeployment();
        return lpToken;
    };

    const lpTokens = {
        USDT_DAI: await deployLPToken("USDT_DAI_LP", "USDTDAI"),
        USDT_wETH: await deployLPToken("USDT_wETH_LP", "USDTwETH"),
        USDT_SHIT: await deployLPToken("USDT_SHIT_LP", "USDTSHIT"),
        DAI_wETH: await deployLPToken("DAI_wETH_LP", "DAIwETH"),
        SHIT_wETH: await deployLPToken("SHIT_wETH_LP", "SHITwETH"),
        DAI_SHIT: await deployLPToken("DAI_SHIT_LP", "DAISHIT"),
    };

    const lpTokenAddresses = {
        USDT_DAI: await lpTokens.USDT_DAI.getAddress(),
        USDT_wETH: await lpTokens.USDT_wETH.getAddress(),
        USDT_SHIT: await lpTokens.USDT_SHIT.getAddress(),
        DAI_wETH: await lpTokens.DAI_wETH.getAddress(),
        SHIT_wETH: await lpTokens.SHIT_wETH.getAddress(),
        DAI_SHIT: await lpTokens.DAI_SHIT.getAddress()
    };

    // 3. 部署流动性池
    const deploySwapPool = async (TokenA, TokenB, LP, Stable = false) => {
        const SwapPool = await hre.ethers.getContractFactory(Stable ? "StableSwapPool" : "NonStableSwapPool");
        const swapPool = await SwapPool.deploy(TokenA, TokenB, LP);
        await swapPool.waitForDeployment();
        return swapPool;
    };

    const swapPools = {
        USDT_DAI: await deploySwapPool(tokenAddresses.USDT, tokenAddresses.DAI, lpTokenAddresses.USDT_DAI, true),
        USDT_wETH: await deploySwapPool(tokenAddresses.USDT, tokenAddresses.wETH, lpTokenAddresses.USDT_wETH),
        USDT_SHIT: await deploySwapPool(tokenAddresses.USDT, tokenAddresses.SHIT, lpTokenAddresses.USDT_SHIT),
        DAI_wETH: await deploySwapPool(tokenAddresses.DAI, tokenAddresses.wETH, lpTokenAddresses.DAI_wETH),
        SHIT_wETH: await deploySwapPool(tokenAddresses.SHIT, tokenAddresses.wETH, lpTokenAddresses.SHIT_wETH),
        DAI_SHIT: await deploySwapPool(tokenAddresses.DAI, tokenAddresses.SHIT, lpTokenAddresses.DAI_SHIT)
    };

    const swapPoolAddresses = {
        USDT_DAI: await swapPools.USDT_DAI.getAddress(),
        USDT_wETH: await swapPools.USDT_wETH.getAddress(),
        USDT_SHIT: await swapPools.USDT_SHIT.getAddress(),
        DAI_wETH: await swapPools.DAI_wETH.getAddress(),
        SHIT_wETH: await swapPools.SHIT_wETH.getAddress(),
        DAI_SHIT: await swapPools.DAI_SHIT.getAddress()
    };

    // 4. 绑定 LPToken 到流动性池
    for (let key in lpTokens) {
        await lpTokens[key].setPool(swapPoolAddresses[key]);
    }

    // 5. 授权并添加流动性
    const liquidityAmount = hre.ethers.parseUnits("500", 18);
    for (let key in swapPools) {
        const [tokenA, tokenB] = key.split("_");
        await token_USDT.approve(swapPoolAddresses[key], initialSupply);
        await token_DAI.approve(swapPoolAddresses[key], initialSupply);
        await token_wETH.approve(swapPoolAddresses[key], initialSupply);
        await token_SHIT.approve(swapPoolAddresses[key], initialSupply);
        await swapPools[key].addLiquidity(liquidityAmount, liquidityAmount, 0);
    }

    console.log("All liquidity pools deployed and initialized.");

    // 6. 写入 JSON 文件
    const deploymentInfo = {
        deployer: deployer.address,
        tokens: tokenAddresses,
        lpTokens: lpTokenAddresses,
        swapPools: swapPoolAddresses
    };

    const filePath = path.join(__dirname, "deployed_contracts.json");
    fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));
    console.log("Deployment info saved to deployed_contracts.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


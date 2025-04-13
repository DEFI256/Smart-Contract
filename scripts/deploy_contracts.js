
// 111
// const { exec } = require("child_process");
// const hre = require("hardhat");
// const fs = require("fs");
// const path = require("path");

// const startGanache = () => {
//     return new Promise((resolve, reject) => {
//         // 启动 Ganache
//         const ganacheCommand = `ganache-cli --db ./ganache-data --mnemonic "labor security egg caught skull labor coyote tennis avoid annual glove rookie"`;
//         const ganacheProcess = exec(ganacheCommand);

//         ganacheProcess.stdout.on("data", (data) => {
//             console.log(data.toString());
//             if (data.includes("Listening on")) {
//                 resolve();
//             }
//         });

//         ganacheProcess.stderr.on("data", (error) => {
//             console.error(error.toString());
//             reject(new Error("Ganache启动失败"));
//         });
//     });
// };

// const deployContracts = async () => {
//     const [deployer] = await hre.ethers.getSigners();
//     console.log("Deploying contracts with the account:", deployer.address);

//     const initialSupply = hre.ethers.parseUnits("1000000000", 0);
    
//     // 1. 部署代币
//     const deployToken = async (name, symbol) => {
//         const Token = await hre.ethers.getContractFactory("Token");
//         const token = await Token.deploy(name, symbol, initialSupply);
//         await token.waitForDeployment();
//         return token;
//     };

//     const token_USDT = await deployToken("Tether USD", "USDT");
//     const token_DAI = await deployToken("Dai Stablecoin", "DAI");
//     const token_wETH = await deployToken("Wrapped Ether", "wETH");
//     const token_SHIT = await deployToken("shit coin", "SHIT");

//     const tokenAddresses = {
//         USDT: await token_USDT.getAddress(),
//         DAI: await token_DAI.getAddress(),
//         wETH: await token_wETH.getAddress(),
//         SHIT: await token_SHIT.getAddress()
//     };

//     // 测试账户
//     const [, secondAccount] = await hre.ethers.getSigners();
//     const testSupply = hre.ethers.parseUnits("100000", 18);

//     for (let token of [token_USDT, token_DAI, token_wETH, token_SHIT]) {
//         await token.transfer(secondAccount.address, testSupply);
//     }

//     // 2. 部署 LPToken
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
//         DAI_SHIT: await deployLPToken("DAI_SHIT_LP", "DAISHIT"),
//     };

//     const lpTokenAddresses = {
//         USDT_DAI: await lpTokens.USDT_DAI.getAddress(),
//         USDT_wETH: await lpTokens.USDT_wETH.getAddress(),
//         USDT_SHIT: await lpTokens.USDT_SHIT.getAddress(),
//         DAI_wETH: await lpTokens.DAI_wETH.getAddress(),
//         SHIT_wETH: await lpTokens.SHIT_wETH.getAddress(),
//         DAI_SHIT: await lpTokens.DAI_SHIT.getAddress()
//     };

//     // 3. 部署流动性池
//     const deploySwapPool = async (TokenA, TokenB, LP, Stable = false) => {
//         const SwapPool = await hre.ethers.getContractFactory(Stable ? "StableSwapPool" : "NonStableSwapPool");
//         const swapPool = await SwapPool.deploy(TokenA, TokenB, LP);
//         await swapPool.waitForDeployment();
//         return swapPool;
//     };

//     const swapPools = {
//         USDT_DAI: await deploySwapPool(tokenAddresses.USDT, tokenAddresses.DAI, lpTokenAddresses.USDT_DAI, true),
//         USDT_wETH: await deploySwapPool(tokenAddresses.USDT, tokenAddresses.wETH, lpTokenAddresses.USDT_wETH),
//         USDT_SHIT: await deploySwapPool(tokenAddresses.USDT, tokenAddresses.SHIT, lpTokenAddresses.USDT_SHIT),
//         DAI_wETH: await deploySwapPool(tokenAddresses.DAI, tokenAddresses.wETH, lpTokenAddresses.DAI_wETH),
//         SHIT_wETH: await deploySwapPool(tokenAddresses.SHIT, tokenAddresses.wETH, lpTokenAddresses.SHIT_wETH),
//         DAI_SHIT: await deploySwapPool(tokenAddresses.DAI, tokenAddresses.SHIT, lpTokenAddresses.DAI_SHIT)
//     };

//     const swapPoolAddresses = {
//         USDT_DAI: await swapPools.USDT_DAI.getAddress(),
//         USDT_wETH: await swapPools.USDT_wETH.getAddress(),
//         USDT_SHIT: await swapPools.USDT_SHIT.getAddress(),
//         DAI_wETH: await swapPools.DAI_wETH.getAddress(),
//         SHIT_wETH: await swapPools.SHIT_wETH.getAddress(),
//         DAI_SHIT: await swapPools.DAI_SHIT.getAddress()
//     };

//     const approvetoken = hre.ethers.parseUnits("10000000", 18);
//     const baseLiquidity = hre.ethers.parseUnits("500000", 18);

//     // 5. 授权并添加流动性
//     for (let key in swapPools) {
//         // 对所有代币进行授权
//         await token_USDT.approve(swapPoolAddresses[key], approvetoken);
//         await token_DAI.approve(swapPoolAddresses[key], approvetoken);
//         await token_wETH.approve(swapPoolAddresses[key], approvetoken);
//         await token_SHIT.approve(swapPoolAddresses[key], approvetoken);

//         if (key === "USDT_DAI") {
//             // USDT_DAI 保持1:1比例
//             await swapPools[key].addLiquidity(baseLiquidity, baseLiquidity, 0);
//         } else {
//             // 其他池子使用随机比例(5:1到1:5之间)
//             const ratio = Math.random() * 4 + 1; // 生成1-5之间的随机数
//             let amountA, amountB;

//             if (Math.random() > 0.5) {
//                 // 50%概率是A:B = ratio:1
//                 amountA = baseLiquidity * BigInt(Math.round(ratio * 1e6)) / BigInt(1e6);
//                 amountB = baseLiquidity;
//             } else {
//                 // 50%概率是A:B = 1:ratio
//                 amountA = baseLiquidity;
//                 amountB = baseLiquidity * BigInt(Math.round(ratio * 1e6)) / BigInt(1e6);
//             }

//             console.log(`Adding liquidity to ${key} with ratio ${amountA.toString()}:${amountB.toString()}`);
//             await swapPools[key].addLiquidity(amountA, amountB, 0);
//         }
//     }

//     console.log("All liquidity pools deployed and initialized.");

//     // 6. 写入 JSON 文件
//     const deploymentInfo = {
//         deployer: deployer.address,
//         test: secondAccount.address,
//         tokens: tokenAddresses,
//         lpTokens: lpTokenAddresses,
//         swapPools: swapPoolAddresses
//     };

//     const filePath = path.join(__dirname, "deployed_contracts.json");
//     fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));
//     console.log("Deployment info saved to deployed_contracts.json");
// };

// const main = async () => {
//     try {
//         // 启动 Ganache
//         await startGanache();
//         console.log("Ganache is up and running!");

//         // 使用 Hardhat 部署合约
//         await hre.run('deploy', { network: 'ganache' });

//         // 部署合约并添加流动性
//         await deployContracts();

//         console.log("All steps completed successfully.");
//     } catch (error) {
//         console.error("Error during deployment:", error);
//     }
// };

// main();


const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const initialSupply = hre.ethers.parseUnits("1000000000", 0);
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

    // 测试账户
    const [, secondAccount] = await ethers.getSigners();
    const testSupply = hre.ethers.parseUnits("100000", 18);

    for (let key in deployToken) {
        await deployToken[key].transfer(secondAccount,testSupply);
    }
    const secondAccount_address = await secondAccount.getAddress()

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

    // const approvetoken = hre.ethers.parseUnits("10000000", 18);
    // // 5. 授权并添加流动性
    // const liquidityAmount = hre.ethers.parseUnits("50000", 18);
    // for (let key in swapPools) {
    //     const [tokenA, tokenB] = key.split("_");
    //     await token_USDT.approve(swapPoolAddresses[key], approvetoken);
    //     await token_DAI.approve(swapPoolAddresses[key], approvetoken);
    //     await token_wETH.approve(swapPoolAddresses[key], approvetoken);
    //     await token_SHIT.approve(swapPoolAddresses[key], approvetoken);
    //     await swapPools[key].addLiquidity(liquidityAmount, liquidityAmount, 0);
    // }

    // console.log("All liquidity pools deployed and initialized.");

    // new method 998,500,000 
    const approvetoken = hre.ethers.parseUnits("10000000", 18);
    const baseLiquidity = hre.ethers.parseUnits("500000", 18);

    // 5. 授权并添加流动性
    for (let key in swapPools) {
        // 对所有代币进行授权
        await token_USDT.approve(swapPoolAddresses[key], approvetoken);
        await token_DAI.approve(swapPoolAddresses[key], approvetoken);
        await token_wETH.approve(swapPoolAddresses[key], approvetoken);
        await token_SHIT.approve(swapPoolAddresses[key], approvetoken);
        
        if (key === "USDT_DAI") {
            // USDT_DAI 保持1:1比例
            await swapPools[key].addLiquidity(baseLiquidity, baseLiquidity, 0);
        } else {
            // 其他池子使用随机比例(5:1到1:5之间)
            const ratio = Math.random() * 4 + 1; // 生成1-5之间的随机数
            let amountA, amountB;
            
            if (Math.random() > 0.5) {
                // 50%概率是A:B = ratio:1
                amountA = baseLiquidity * BigInt(Math.round(ratio * 1e6)) / BigInt(1e6);
                amountB = baseLiquidity;
            } else {
                // 50%概率是A:B = 1:ratio
                amountA = baseLiquidity;
                amountB = baseLiquidity * BigInt(Math.round(ratio * 1e6)) / BigInt(1e6);
            }
            
            console.log(`Adding liquidity to ${key} with ratio ${amountA.toString()}:${amountB.toString()}`);
            await swapPools[key].addLiquidity(amountA, amountB, 0);
        }
    }

    console.log("All liquidity pools deployed and initialized.");

    // 6. 写入 JSON 文件
    const deploymentInfo = {
        deployer: deployer.address,
        test: secondAccount_address,
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


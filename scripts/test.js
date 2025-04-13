const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    const [signer] = await hre.ethers.getSigners();

    const filePath = path.join(__dirname, "deployed_contracts.json");
    const deploymentData = JSON.parse(fs.readFileSync(filePath, "utf8"));
    const swapPoolAddresses = deploymentData.swapPools;

    const amountForTest = hre.ethers.parseUnits("100", 5); // 100 个单位测试用
    for (let pair in swapPoolAddresses) {
        const address = swapPoolAddresses[pair];
        const isStable = pair === "USDT_DAI"; // 你可以换成白名单机制
        const contractName = isStable ? "StableSwapPool" : "NonStableSwapPool";
        const pool = await hre.ethers.getContractAt(contractName, address, signer);

        console.log(`\n--- Testing ${pair} (${contractName}) ---`);

        try {
            const tokenA = await pool.tokenA();
            const tokenB = await pool.tokenB();
            const lpToken = await pool.lpToken();
            const reserveA = await pool.reserveA();
            const reserveB = await pool.reserveB();

            console.log(`Token A: ${tokenA}`);
            console.log(`Token B: ${tokenB}`);
            console.log(`LP Token: ${lpToken}`);
            console.log(`Reserves: A=${reserveA.toString()}, B=${reserveB.toString()}`);

            // getReservesAndLiquidity
            const [rA, rB, totalLiq, price] = await pool.getReservesAndLiquidity();
            console.log(`Reserves & Liquidity -> A: ${rA}, B: ${rB}, Total Liquidity: ${totalLiq}, Price: ${price}`);

            // getSwapDetails A -> B
            const [fee1, out1, impact1] = await pool.getSwapDetails(amountForTest, true);
            console.log(`Swap A -> B -> Fee: ${fee1}, Estimated Out: ${out1}, Price Impact: ${impact1}`);

            // getSwapDetails B -> A
            const [fee2, out2, impact2] = await pool.getSwapDetails(amountForTest, false);
            console.log(`Swap B -> A -> Fee: ${fee2}, Estimated Out: ${out2}, Price Impact: ${impact2}`);

            // getPairedAmount
            const pairedA = await pool.getPairedAmount(amountForTest, true);
            const pairedB = await pool.getPairedAmount(amountForTest, false);
            console.log(`Paired Amount A -> B: ${pairedA}, B -> A: ${pairedB}`);

            // 如果是稳定池，打印虚拟价格
            if (isStable && pool.getVirtualPrice) {
                const vPrice = await pool.getVirtualPrice();
                console.log(`Virtual Price: ${vPrice.toString()}`);
            }
            
            } catch (err) {
                console.error(`Error testing ${pair}:`, err.message);
            }
        }

    // for (let pair in swapPoolAddresses) {
    //     const address = swapPoolAddresses[pair];
    //     const isStable = pair === "USDT_DAI"; // 你可以根据需求调整判断规则
    //     const contractName = isStable ? "StableSwapPool" : "NonStableSwapPool";
    //     const pool = await hre.ethers.getContractAt(contractName, address, signer);

    //     console.log(`\n--- Testing ${pair} (${contractName}) ---`);

    //     try {
    //         const tokenA = await pool.tokenA();
    //         const tokenB = await pool.tokenB();
    //         const lpToken = await pool.lpToken();
    //         const reserveA = await pool.reserveA();
    //         const reserveB = await pool.reserveB();

    //         console.log(`Token A: ${tokenA}`);
    //         console.log(`Token B: ${tokenB}`);
    //         console.log(`LP Token: ${lpToken}`);
    //         console.log(`Reserves: A=${reserveA.toString()}, B=${reserveB.toString()}`);

    //         if (isStable && pool.getVirtualPrice) {
    //             const vPrice = await pool.getVirtualPrice();
    //             console.log(`Virtual Price: ${vPrice.toString()}`);
    //         }

    //         // 你可以继续添加自定义函数测试：
    //         // const D = await pool.getD();
    //         // const gamma = await pool.getGamma();
    //         // const fee = await pool.getFee();
    //         // console.log(`D: ${D}, gamma: ${gamma}, fee: ${fee}`);





        // } catch (err) {
        //     console.error(`Error testing ${pair}:`, err.message);
        // }
    // }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error("Script failed:", err);
        process.exit(1);
    });

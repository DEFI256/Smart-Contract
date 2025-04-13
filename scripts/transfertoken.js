const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    // 加载部署后的地址信息
    const deployed = JSON.parse(
        fs.readFileSync(path.join(__dirname, "deployed_contracts.json"), "utf8")
    );

    const [deployer, secondAccount] = await hre.ethers.getSigners();
    const secondAccountAddress = deployed.test;
    const testSupply = hre.ethers.parseUnits("100000", 18);

    const tokenAddresses = deployed.tokens;
    const deployToken = {};

    // 获取每个 token 合约实例
    for (let symbol in tokenAddresses) {
        const Token = await hre.ethers.getContractFactory("Token");
        const token = await Token.attach(tokenAddresses[symbol]);
        deployToken[symbol] = token;
    }

    // 执行转账
    for (let key in deployToken) {
        const tx = await deployToken[key].transfer(secondAccountAddress, testSupply);
        await tx.wait();
        console.log(`Transferred ${testSupply} ${key} to ${secondAccountAddress}`);
    }

    console.log("transfer complete");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

// const { exec } = require("child_process");

// console.log("Starting Ganache with persistent database...");
// exec('start cmd /k "ganache-cli --db ./ganache-data"', (error) => {
//     if (error) {
//         console.error(`Failed to start Ganache: ${error.message}`);
//         return;
//     }
// });

//     // 再等待 5 秒，确保 Hardhat 节点启动
//     setTimeout(() => {
//         console.log("Deploying contracts in a new terminal...");
//         exec('start cmd /k "npx hardhat run scripts/deploy_contracts.js --network localhost"', (error) => {
//             if (error) {
//                 console.error(`Failed to deploy contracts: ${error.message}`);
//                 return;
//             }
//         });
//     }, 5000);
// }, 5000);

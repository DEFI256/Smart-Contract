require("@nomicfoundation/hardhat-toolbox");
const { mnemonic } = require("./secrets.json");

// module.exports = {
//   solidity: "0.8.28",
//   // ,"0.8.20",
//   networks: {
//     hardhat: {},
//     ganache: {
//       url: "http://127.0.0.1:8545", 
//       accounts:{ mnemonic } 
//     },
//   },
// };

require('hardhat-deploy');
// require('hardhat-deploy-ethers'); 
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
      },
      {
        version: "0.8.20",
      },
      {
        version: "0.8.28",
      },
    ],
  },// 选择你的 Solidity 版本
  networks: {
    hardhat: {
      // 本地测试网络的配置
    },
    ganache: {
      url: "http://127.0.0.1:8545", 
      accounts:{ mnemonic } ,
      saveDeployments: true, // 用来保存部署信息
    }
  },
  namedAccounts: {
    deployer: {
      default: 0, // 默认使用账户 0 作为部署者
    },
    user: {
      default: 1,  // 默认为第二个账户
    }
  }
};

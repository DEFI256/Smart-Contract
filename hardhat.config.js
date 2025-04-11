require("@nomicfoundation/hardhat-toolbox");
const { mnemonic } = require("./secrets.json");

module.exports = {
  solidity: "0.8.28",
  // ,"0.8.20",
  networks: {
    hardhat: {},
    ganache: {
      url: "http://127.0.0.1:8545", 
      accounts:{ mnemonic } 
    },
  },
};

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token_A is ERC20, Ownable {
    //  初始化合约 ERC20(name, symbol) Ownable(msg.sender)
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) Ownable(msg.sender){
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    // 允许任何用户领取指定数量的代币
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

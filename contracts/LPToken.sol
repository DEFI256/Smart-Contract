// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LPToken is ERC20, Ownable {
    address public pool; // 只允许池子合约调用 mint/burn

    modifier onlyPool() {
        require(msg.sender == pool, "Only pool can call this function");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender){}

    /** @dev 绑定流动性池合约（只能设置一次） */
    function setPool(address _pool) external onlyOwner {
        require(pool == address(0), "Pool already set");
        pool = _pool;
    }

    /** @dev 给流动性提供者铸造 LP 代币 */
    function mint(address to, uint256 amount) external onlyPool {
        _mint(to, amount);
    }

    /** @dev 销毁 LP 代币（用户提取流动性时调用） */
    function burn(address from, uint256 amount) external onlyPool {
        _burn(from, amount);
    }
}

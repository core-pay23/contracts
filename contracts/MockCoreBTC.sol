// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockCoreBTC
 * @dev Mock CoreBTC token for testing payment gateway (anyone can mint)
 */
contract MockCoreBTC is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        // Mint initial supply for deployer (1 BTC)
        _mint(msg.sender, 1 * 10**decimals_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Anyone can mint tokens for testing
     * @param to Address to mint tokens to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev Faucet function for testing - anyone can get 0.1 BTC
     */
    function faucet() external {
        _mint(msg.sender, 1e7); // 0.1 BTC if 8 decimals
    }
}

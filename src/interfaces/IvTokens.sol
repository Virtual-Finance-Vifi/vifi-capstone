// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IvTokens {
    // View functions
    function parentContract() external view returns (address);
    function tokenId() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function vCurrencyId() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    // State-changing functions
    function transfer(address receiver, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 amount) external returns (bool);
}
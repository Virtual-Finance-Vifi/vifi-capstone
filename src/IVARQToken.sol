// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

interface IVARQToken {
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function calculateTotalSupply(uint256 tokenId) external view returns (uint256);
} 
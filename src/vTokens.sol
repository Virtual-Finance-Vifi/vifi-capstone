// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IVARQToken.sol";
import "./VARQ.sol";

contract vTokens {
    address public parentContract;
    uint256 public tokenId;
    string public tokenName;
    string public tokenSymbol;
    uint8 public tokenDecimals;

    constructor(address _parentContract, uint256 _tokenId, string memory name_, string memory symbol_, uint8 decimals_) {
        parentContract = _parentContract;
        tokenId = _tokenId;
        tokenName = name_;
        tokenSymbol = symbol_;
        tokenDecimals = decimals_;
    }

    function name() public view returns (string memory) {
        return tokenName;
    }

    function symbol() public view returns (string memory) {
        return tokenSymbol;
    }

    function decimals() public view returns (uint8) {
        return tokenDecimals;
    }

    function totalSupply() public view returns (uint256) {
        VARQ parentContractInstance = VARQ(parentContract);
        return parentContractInstance.calculateTotalSupply(tokenId);
    }

    function balanceOf(address owner) public view returns (uint256) {
        return IERC6909(parentContract).balanceOf(owner, tokenId);
    }

    function transfer(address receiver, uint256 amount) public returns (bool) {
        return IERC6909(parentContract).transfer(receiver, tokenId, amount);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        return IERC6909(parentContract).approve(spender, tokenId, amount);
    }

    function transferFrom(address sender, address receiver, uint256 amount) public returns (bool) {
        return IERC6909(parentContract).transferFrom(sender, receiver, tokenId, amount);
    }
}

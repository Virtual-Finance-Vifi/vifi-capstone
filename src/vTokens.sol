// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IVARQ.sol";
import "./VARQ.sol";
import "./interfaces/IvTokens.sol";

contract vTokens is IvTokens {
    address public parentContract;
    uint256 public tokenId;
    string public tokenName;
    string public tokenSymbol;
    uint8 public tokenDecimals;
    uint256 public vCurrencyId;

    constructor(address _parentContract, uint256 _tokenId, string memory name_, string memory symbol_, uint8 decimals_, uint256 _vCurrencyId) {
        parentContract = _parentContract;
        tokenId = _tokenId;
        tokenName = name_;
        tokenSymbol = symbol_;
        tokenDecimals = decimals_;
        vCurrencyId = _vCurrencyId;
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

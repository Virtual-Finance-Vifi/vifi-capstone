// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVARQ {
    struct vTokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        address proxyAddress;
        uint256 vCurrencyId;
    }

    struct vCurrencyState {
        uint256 tokenIdFiat;
        uint256 tokenIdReserve;
        uint256 oracleRate;
        uint256 S_u;
        uint256 S_f;
        uint256 S_r;
        address oracleUpdater;
    }

    // Main vCurrency functions
    function mintvCurrency(uint256 currencyId, uint256 amount) external;
    function burnvCurrency(uint256 currencyId, uint256 amount) external;
    
    // USD handling
    function depositUSD(uint256 amount) external;
    function withdrawUSD(uint256 amount) external;
    
    // Oracle functions
    function updateOracleRate(uint256 currencyId, uint256 newRate) external;
    function updateOracleUpdater(uint256 currencyId, address newUpdater) external;
    
    // View functions
    function vCurrencyStates(uint256 currencyId) external view returns (vCurrencyState memory);
    function tokenMetadatas(uint256 id) external view returns (vTokenMetadata memory);
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function calculateTotalSupply(uint256 tokenId) external view returns (uint256);
    function getNextTokenId() external view returns (uint256);
    function getNextvCurrencyId() external view returns (uint256);

    // Events
    event vCurrencyStateAdded(uint256 currencyId, uint256 tokenIdFiat, uint256 tokenIdReserve);
    event OracleRateUpdated(uint256 currencyId, uint256 newRate);
    event OracleUpdaterUpdated(uint256 currencyId, address newUpdater);
    event Transfer(address indexed operator, address from, address to, uint256 id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event OracleUpdated(address newUpdater);

    // Add ERC6909 functions
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);
    function allowance(address owner, address spender, uint256 id) external view returns (uint256);
    function setOperator(address operator, bool approved) external returns (bool);
    function isOperator(address owner, address operator) external view returns (bool);
    function approveFor(address owner, address spender, uint256 id, uint256 amount) external returns (bool);

    // Add new structs
    struct vCurrencyPool {
        address uniswapPair;
        uint256 lockEndTime;
        uint256 yieldAccrued;
        bool isTerminated;
        uint256 terminationRate;
        uint256 totalLockedVUSD;
        uint256 lastYieldUpdate;
        uint256 yieldPerTokenStored;
        uint256 totalRQTStaked;
    }

    struct vCurrencyProposal {
        string name;
        string symbol;
        address oracleAddress;
        uint256 totalStaked;
        uint256 proposedRatio;
        uint256 minStakeRequired;
        bool isActive;
    }

    struct StakeInfo {
        uint256 amountStaked;
        uint256 proposedRatio;
        uint256 timestamp;
    }

    struct LockedLP {
        uint256 vusdAmount;
        uint256 liquidityAmount;
        uint256 unlockTime;
        bool claimed;
    }

    // Add new functions
    function checkTerminationConditions(uint256 currencyId) external returns (bool);
    function claimTerminatedVCurrency(uint256 currencyId, uint256 amount, bool isFiat) external;
    function earned(uint256 currencyId, address user) external view returns (uint256);
    function withdrawLockedLP(uint256 currencyId) external;
}
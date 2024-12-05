// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./vTokens.sol";

interface IERC6909 {
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function totalSupply(uint256 id) external view returns (uint256);
}

contract VARQ is Ownable {

    IERC20 public usdcToken;

    struct vTokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        address proxyAddress;
    }

    struct NationState {
        uint256 tokenIdCurrency;
        uint256 tokenIdReserve;
        uint256 oracleRate;
        uint256 S_u;
        uint256 S_f;
        uint256 S_r;
        address oracleUpdater;
    }

    mapping(uint256 => vTokenMetadata) public tokenMetadatas;
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;
    mapping(address => mapping(address => bool)) public isOperator;
    mapping(uint256 => address) public tokenProxies;
    mapping(uint256 => NationState) public nationStates;

    event NationStateAdded(uint256 nationId, uint256 tokenIdCurrency, uint256 tokenIdReserve);
    event OracleRateUpdated(uint256 nationId, uint256 newRate);
    event OracleUpdaterUpdated(uint256 nationId, address newUpdater);
    event Transfer(address indexed operator, address from, address to, uint256 id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    constructor(address initialOwner, address _usdcToken) Ownable(initialOwner) {
        usdcToken = IERC20(_usdcToken);
        _createTokenProxy(1, "vUSD", "vUSD", 18);
    }

    function addNationState(uint256 nationId, string memory currencyName, string memory reserveName, address oracleUpdater) public onlyOwner {
        require(nationStates[nationId].tokenIdCurrency == 0, "Nation-state already exists");
        uint256 tokenIdCurrency = nationId * 2;
        uint256 tokenIdReserve = nationId * 2 + 1;

        _createTokenProxy(tokenIdCurrency, currencyName, string(abi.encodePacked("v", currencyName)), 18);
        _createTokenProxy(tokenIdReserve, reserveName, string(abi.encodePacked("vRQT_", currencyName)), 18);

        nationStates[nationId] = NationState(tokenIdCurrency, tokenIdReserve, 0, 0, 0, 0, oracleUpdater);

        emit NationStateAdded(nationId, tokenIdCurrency, tokenIdReserve);
    }

    function updateOracleRate(uint256 nationId, uint256 newRate) public {
        NationState storage nation = nationStates[nationId];
        require(msg.sender == nation.oracleUpdater, "Not authorized to update oracle");
        nation.oracleRate = newRate;
        emit OracleRateUpdated(nationId, newRate);
    }

    function updateOracleUpdater(uint256 nationId, address newUpdater) public onlyOwner {
        NationState storage nation = nationStates[nationId];
        nation.oracleUpdater = newUpdater;
        emit OracleUpdaterUpdated(nationId, newUpdater);
    }

    function mintNationCurrency(uint256 nationId, uint256 amount) public {
        NationState storage nation = nationStates[nationId];
        require(nation.tokenIdCurrency != 0, "Nation-state does not exist");
        require(nation.oracleRate > 0, "Oracle rate cannot be zero");
        require(balanceOf[msg.sender][1] >= amount, "Insufficient vUSD balance");

        _burn(msg.sender, 1, amount);
        uint256 nationAmount = (amount * nation.oracleRate) / 1e18; // Normalize to 18 decimals

        uint256 protocolRate = _calculateProtocolRate(nation.S_f, nation.S_r);
        uint256 fluxRatio = _calculateFluxRatio(protocolRate, nation.oracleRate);
        uint256 reserveRatio = _calculateReserveRatio(nation.S_u, nation.S_r);

        uint256 fluxInfluence = _calculateFluxInfluence(fluxRatio, reserveRatio);

        uint256 reserveAmount = (amount * fluxInfluence) / 1e18; // Normalize back to non-decimal amount

        _mint(msg.sender, nation.tokenIdCurrency, nationAmount);
        _mint(msg.sender, nation.tokenIdReserve, reserveAmount);

        nation.S_u += amount; // Depending on your model, consider normalization here too
        nation.S_f += nationAmount;
        nation.S_r += reserveAmount;
    }


    function burnNationCurrency(uint256 nationId, uint256 amount) public {
        NationState storage nation = nationStates[nationId];
        require(nation.tokenIdCurrency != 0, "Nation-state does not exist");
        require(balanceOf[msg.sender][nation.tokenIdCurrency] >= amount, "Insufficient nation currency balance");

        uint256 protocolRate = _calculateProtocolRate(nation.S_f, nation.S_r);
        uint256 usdAmount = (amount * 1e18) / protocolRate; // Normalize the result

        require(balanceOf[msg.sender][nation.tokenIdReserve] >= usdAmount, "Insufficient reserve quota token balance");
        require(nation.S_u >= usdAmount, "Insufficient S_u supply");

        _burn(msg.sender, nation.tokenIdCurrency, amount);
        _burn(msg.sender, nation.tokenIdReserve, usdAmount);

        _mint(msg.sender, 1, usdAmount);

        nation.S_u -= usdAmount;
        nation.S_f -= amount;
        nation.S_r -= usdAmount;
    }

    function depositUSD(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        bool success = usdcToken.transferFrom(msg.sender, address(this), amount);
        require(success, "USDC transfer failed");

        _mint(msg.sender, 1, amount);
    }

    function withdrawUSD(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf[msg.sender][1] >= amount, "Insufficient vUSD balance");

        _burn(msg.sender, 1, amount);
        bool success = usdcToken.transfer(msg.sender, amount);
        require(success, "USDC transfer failed");
    }

    // Returns the protocol rate normalized to 18 decimal places
    function _calculateProtocolRate(uint256 S_f, uint256 S_r) internal pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_f * 1e18) / S_r;
    }

    // Returns the flux ratio normalized to 18 decimal places
    function _calculateFluxRatio(uint256 protocolRate, uint256 oracleRate) internal pure returns (uint256) {
        require(oracleRate > 0, "oracleRate cannot be zero");
        return (protocolRate * 1e18) / oracleRate;
    }

    // Returns the reserve ratio normalized to 18 decimal places
    function _calculateReserveRatio(uint256 S_u, uint256 S_r) internal pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_u * 1e18) / S_r;
    }

    // Calculates flux influence, taking into account normalization where necessary
    function _calculateFluxInfluence(uint256 fluxRatio, uint256 reserveRatio) internal pure returns (uint256) {
        if (fluxRatio > 1e18 && reserveRatio <= 1e18) {
            return 1e18; // normalize to 18 decimal places
        } else {
            return fluxRatio; // already normalized
        }
    }

    function _mint(address receiver, uint256 id, uint256 amount) internal {
        tokenMetadatas[id].totalSupply += amount;
        balanceOf[receiver][id] += amount;
        emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal {
        require(balanceOf[sender][id] >= amount, "Insufficient balance to burn");
        tokenMetadatas[id].totalSupply -= amount;
        balanceOf[sender][id] -= amount;
        emit Transfer(msg.sender, sender, address(0), id, amount);
    }

    function _createTokenProxy(uint256 id, string memory name_, string memory symbol_, uint8 decimals_) internal {
        vTokens proxy = new vTokens(address(this), id, name_, symbol_, decimals_);
        tokenMetadatas[id] = vTokenMetadata(name_, symbol_, decimals_, 0, address(proxy));
        tokenProxies[id] = address(proxy);
    }

    function calculateTotalSupply(uint256 tokenId) public view returns (uint256) {
        return tokenMetadatas[tokenId].totalSupply;
    }
}
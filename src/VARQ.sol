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

    struct vCurrencyState {
        uint256 tokenIdFiat;
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
    mapping(uint256 => vCurrencyState) public vCurrencyStates;

    event vCurrencyStateAdded(uint256 currencyId, uint256 tokenIdFiat, uint256 tokenIdReserve);
    event OracleRateUpdated(uint256 currencyId, uint256 newRate);
    event OracleUpdaterUpdated(uint256 currencyId, address newUpdater);
    event Transfer(address indexed operator, address from, address to, uint256 id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    // Add counters for both token IDs and nation IDs
    uint256 private nextTokenId = 2;    // Start at 2 since vUSD is token ID 1
    uint256 private nextvCurrencyId = 1;   // Start nation IDs at 1

    constructor(address initialOwner, address _usdcToken) Ownable(initialOwner) {
        usdcToken = IERC20(_usdcToken);
        _createTokenProxy(1, "vUSD", "vUSD", 18);
    }

    function addvCurrencyState(
        string memory fiatName, 
        string memory reserveName, 
        address oracleUpdater
    ) public onlyOwner returns (uint256) {
        uint256 currencyId = nextvCurrencyId++;  // Auto-increment nation ID
        
        require(vCurrencyStates[currencyId].tokenIdFiat == 0, "Nation-state already exists");
        require(oracleUpdater != address(0), "Oracle updater cannot be zero address");
        
        // Use nextTokenId for token IDs
        uint256 tokenIdFiat = nextTokenId;
        uint256 tokenIdReserve = nextTokenId + 1;
        nextTokenId += 2;  // Increment by 2 for the next pair

        _createTokenProxy(tokenIdFiat, fiatName, string(abi.encodePacked("v", fiatName)), 18);
        _createTokenProxy(tokenIdReserve, reserveName, string(abi.encodePacked("vRQT_", fiatName)), 18);

        vCurrencyStates[currencyId] = vCurrencyState(
            tokenIdFiat, 
            tokenIdReserve, 
            0, 
            0, 
            0, 
            0, 
            oracleUpdater
        );

        emit vCurrencyStateAdded(currencyId, tokenIdFiat, tokenIdReserve);
        return currencyId;  // Return the assigned currencyId
    }

    function updateOracleRate(uint256 currencyId, uint256 newRate) public {
        vCurrencyState storage nation = vCurrencyStates[currencyId];
        require(msg.sender == nation.oracleUpdater, "Not authorized to update oracle");
        nation.oracleRate = newRate;
        emit OracleRateUpdated(currencyId, newRate);
    }

    function updateOracleUpdater(uint256 currencyId, address newUpdater) public onlyOwner {
        vCurrencyState storage nation = vCurrencyStates[currencyId];
        nation.oracleUpdater = newUpdater;
        emit OracleUpdaterUpdated(currencyId, newUpdater);
    }

    function mintvCurrency(uint256 currencyId, uint256 amount) public {
        vCurrencyState storage nation = vCurrencyStates[currencyId];
        require(nation.tokenIdFiat != 0, "Nation-state does not exist");
        require(nation.oracleRate > 0, "Oracle rate cannot be zero");
        require(balanceOf[msg.sender][1] >= amount, "Insufficient vUSD balance");

        _burn(msg.sender, 1, amount);
        uint256 nationAmount = (amount * nation.oracleRate) / 1e18; // Normalize to 18 decimals

        // Handle initial minting case
        if (nation.S_r == 0) {
            // For the first mint, we set initial ratios
            nation.S_u = amount;
            nation.S_f = nationAmount;
            nation.S_r = amount; // Initialize S_r with the full amount
            _mint(msg.sender, nation.tokenIdFiat, nationAmount);
            _mint(msg.sender, nation.tokenIdReserve, amount);
            return;
        }

        uint256 protocolRate = _calculateProtocolRate(nation.S_f, nation.S_r);
        uint256 fluxRatio = _calculateFluxRatio(protocolRate, nation.oracleRate);
        uint256 reserveRatio = _calculateReserveRatio(nation.S_u, nation.S_r);

        uint256 fluxInfluence = _calculateFluxInfluence(fluxRatio, reserveRatio);

        uint256 reserveAmount = (amount * fluxInfluence) / 1e18; // Normalize back to non-decimal amount

        _mint(msg.sender, nation.tokenIdFiat, nationAmount);
        _mint(msg.sender, nation.tokenIdReserve, reserveAmount);

        nation.S_u += amount;
        nation.S_f += nationAmount;
        nation.S_r += reserveAmount;
    }


    function burnvCurrency(uint256 currencyId, uint256 amount) public {
        vCurrencyState storage nation = vCurrencyStates[currencyId];
        require(nation.tokenIdFiat != 0, "Nation-state does not exist");
        require(balanceOf[msg.sender][nation.tokenIdFiat] >= amount, "Insufficient nation currency balance");

        uint256 protocolRate = _calculateProtocolRate(nation.S_f, nation.S_r);
        uint256 usdAmount = (amount * 1e18) / protocolRate; // Normalize the result

        require(balanceOf[msg.sender][nation.tokenIdReserve] >= usdAmount, "Insufficient reserve quota token balance");
        require(nation.S_u >= usdAmount, "Insufficient S_u supply");

        _burn(msg.sender, nation.tokenIdFiat, amount);
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
    function _calculateProtocolRate(uint256 S_f, uint256 S_r) public pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_f * 1e18) / S_r;
    }

    // Returns the flux ratio normalized to 18 decimal places
    function _calculateFluxRatio(uint256 protocolRate, uint256 oracleRate) public pure returns (uint256) {
        require(oracleRate > 0, "oracleRate cannot be zero");
        return (protocolRate * 1e18) / oracleRate;
    }

    // Returns the reserve ratio normalized to 18 decimal places
    function _calculateReserveRatio(uint256 S_u, uint256 S_r) public pure returns (uint256) {
        require(S_r > 0, "S_r cannot be zero");
        return (S_u * 1e18) / S_r;
    }

    // Calculates flux influence, taking into account normalization where necessary
    function _calculateFluxInfluence(uint256 fluxRatio, uint256 reserveRatio) public pure returns (uint256) {
        if (fluxRatio > 1e18 && reserveRatio <= 1e18) {
            return 1e18; // normalize to 18 decimal places
        } else {
            return fluxRatio; // already normalized
        }
    }

    function calculateFluxDiff(uint256 protocolRate, uint256 oracleRate) public pure returns (uint256) {
        uint256 difference;
        if (protocolRate > oracleRate) {
            difference = protocolRate - oracleRate;
        } else {
            difference = oracleRate - protocolRate;
        }

        // Calculate the relative difference as a proportion of oracleRate
        uint256 relativeDifference = (difference * 1e18) / oracleRate;  // This gives us 0.03e18 for 3%

        // k value for sensitivity - dramatically increased
        uint256 k = 241049 * 1e14;  // Increased by 100x again (about 231 billion)

        // Calculate exponent term with better scaling
        uint256 kx = (k * relativeDifference) / 1e18;  // Direct scaling
        
        // Calculate e^(-kx)
        uint256 expKx = approximateExp(kx);

        // Return 1 - e^(-kx)
        return 1e18 - expKx;
    }

    function approximateExp(uint256 x) internal pure returns (uint256) {
        // Start with 1.0
        uint256 result = 1e18;
        
        // Add x term
        result = result - ((x * 1e18) / 1e18);
        
        // Add x^2/2 term
        uint256 term = (x * x) / 1e18;  // x^2
        result = result + ((term * 1e18) / 2) / 1e18;
        
        // Add x^3/6 term
        term = (term * x) / 1e18;  // x^3
        result = result - ((term * 1e18) / 6) / 1e18;
        
        return result;
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

    /*//////////////////////////////////////////////////////////////
                              ERC6909 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender][id] -= amount;
        balanceOf[receiver][id] += amount;
        emit Transfer(msg.sender, msg.sender, receiver, id, amount);
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        if (msg.sender != sender && !isOperator[sender][msg.sender]) {
            uint256 allowed = allowance[sender][msg.sender][id];
            if (allowed != type(uint256).max) allowance[sender][msg.sender][id] = allowed - amount;
        }

        balanceOf[sender][id] -= amount;
        balanceOf[receiver][id] += amount;
        emit Transfer(msg.sender, sender, receiver, id, amount);
        return true;
    }

    function approve(address spender, uint256 id, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    function setOperator(address operator, bool approved) public virtual returns (bool) {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // Optional: Add a view function to check the next token ID
    function getNextTokenId() public view returns (uint256) {
        return nextTokenId;
    }

    // Optional: Add view functions to check the next available IDs
    function getNextvCurrencyId() public view returns (uint256) {
        return nextvCurrencyId;
    }
}
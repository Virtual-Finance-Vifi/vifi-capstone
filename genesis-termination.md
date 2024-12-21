vCurrency Genesis:

There needs to be a vCurrency proposal which has the ticker symbol name and orcale address

when the owner of the VARQ approves the proposal

it allows users to stake vUSD and indicate an opening pair ratio

once a threshold of 10M vUSD is hit

the owner can then begin the vCurrency Gensis.

a weighted average of vusd staked and pair ratio would determine the final opening ratio

all the vUSD is then converted into a vCurrency pair and added as liquidity into a AMM unsiwap v2 pool

the LP is locked for 30 days.

the LP accures yield from the underlaying callateral and LP can claim vUSD on withdrawal.

there is a vCurrency termination whereby

if the Liquity reserves in either vRQT or vFiat falls below 10% of the supply, swaps are closed

vRQT to vFiat raio is compared aginst all the vUSD burned to create it (S_u)

this then prices in a single token claim to vUSD

so vFiat can be claimed for vUSD at the protocol rate

and vRQT can be claimed at the last raio of the uniswap pool

effectively allow no new vCurrency mints, but direct claims to vUSD

---

//new structures
struct vCurrencyProposal {
string name;
string symbol;
address oracleAddress;
uint256 totalStaked;
uint256 proposedRatio; // weighted average of staker inputs
uint256 minStakeRequired; // 10M vUSD
bool isActive;
mapping(address => StakeInfo) stakers;
}

struct StakeInfo {
uint256 amountStaked;
uint256 proposedRatio;
uint256 timestamp;
}

struct vCurrencyPool {
address uniswapPair;
uint256 lockEndTime;
uint256 yieldAccrued;
bool isTerminated;
uint256 terminationRate; // Final redemption rate for vRQT
}

---

//new state variables
mapping(uint256 => vCurrencyProposal) public proposals;
mapping(uint256 => vCurrencyPool) public pools;
uint256 public nextProposalId;

// Minimum reserves threshold (10%)
uint256 public constant MIN_RESERVES_THRESHOLD = 1e17; // 0.1 in 1e18

---

//Add Genesis functions
function proposeVCurrency(
string memory \_name,
string memory \_symbol,
address \_oracleAddress,
uint256 \_proposedRatio
) external returns (uint256 proposalId) {
proposalId = nextProposalId++;
vCurrencyProposal storage proposal = proposals[proposalId];
proposal.name = \_name;
proposal.symbol = \_symbol;
proposal.oracleAddress = \_oracleAddress;
proposal.minStakeRequired = 10_000_000 \* 1e18; // 10M vUSD
proposal.isActive = true;

    // Initial stake from proposer
    _stakeForProposal(proposalId, _proposedRatio);

    emit VCurrencyProposed(proposalId, _name, _symbol);
    return proposalId;

}

function stakeForProposal(
uint256 proposalId,
uint256 amount,
uint256 proposedRatio
) external {
require(proposals[proposalId].isActive, "Proposal not active");
\_stakeForProposal(proposalId, amount, proposedRatio);
}

function initiateGenesis(uint256 proposalId) external onlyOwner {
vCurrencyProposal storage proposal = proposals[proposalId];
require(proposal.totalStaked >= proposal.minStakeRequired, "Insufficient stake");

    // Create vCurrency pair
    uint256 currencyId = addvCurrencyState(
        proposal.name,
        proposal.symbol,
        proposal.oracleAddress
    );

    // Setup Uniswap pool and lock liquidity
    _setupUniswapPool(currencyId, proposal);

    emit VCurrencyGenesis(currencyId, proposal.totalStaked);

}

---

//Add Termination functions
function checkTerminationConditions(uint256 currencyId) public returns (bool) {
vCurrencyState storage state = \_vCurrencyStates[currencyId];
vCurrencyPool storage pool = pools[currencyId];

    uint256 reserveRatio = _calculateReserveRatio(state.S_f, state.S_r);
    if (reserveRatio < MIN_RESERVES_THRESHOLD) {
        pool.isTerminated = true;
        pool.terminationRate = _calculateTerminationRate(currencyId);
        emit VCurrencyTerminated(currencyId, pool.terminationRate);
        return true;
    }
    return false;

}

function claimTerminatedVCurrency(
uint256 currencyId,
uint256 amount,
bool isFiat
) external {
vCurrencyPool storage pool = pools[currencyId];
require(pool.isTerminated, "Not terminated");

    if (isFiat) {
        // Claim vFiat at protocol rate
        uint256 vusdAmount = _calculateVUSDClaim(currencyId, amount, true);
        _burn(msg.sender, _vCurrencyStates[currencyId].tokenIdFiat, amount);
        _mint(msg.sender, 1, vusdAmount);
    } else {
        // Claim vRQT at termination rate
        uint256 vusdAmount = _calculateVUSDClaim(currencyId, amount, false);
        _burn(msg.sender, _vCurrencyStates[currencyId].tokenIdReserve, amount);
        _mint(msg.sender, 1, vusdAmount);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./EquityToken.sol";
import "@openzeppelin/contracts@4.9.6/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.6/utils/math/Math.sol";

/// @notice Ein ETH-Verkauf mit Claims/Refunds und Governance fuer die zweite Tranche.
contract CrowdfundingProject is ReentrancyGuard {
    enum SaleStatus { Active, Successful, Failed }
    enum ProposalState { Pending, Active, AwaitingFinalization, Defeated, Succeeded, Executed }

    struct SaleTerms {
        uint256 priceWeiPerToken;
        uint256 offeredTokens;
        uint256 minSoldTokens;
        uint256 duration;
    }

    struct Sale {
        SaleTerms terms;
        uint256 startTime;
        uint256 endTime;
        SaleStatus status;
        uint256 soldTokens;
        uint256 raisedWei;
        uint256 claimedTokens;
        uint256 refundedWei;
        bool initialWithdrawn;
        bool governedWithdrawn;
    }

    struct Proposal {
        uint256 snapshotBlock;
        uint256 endBlock;
        uint256 eligibleBase;
        uint256 forVotes;
        uint256 againstVotes;
        bool finalized;
        bool approved;
        bool executed;
    }

    address public immutable company;
    uint256 public immutable companyAllocation;
    EquityToken public immutable token;
    uint256 public constant VOTING_PERIOD_BLOCKS = 50;
    uint256 public proposalCount;
    uint256 public openProposalId;

    Sale private sale;
    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256) public purchasedTokens;
    mapping(address => bool) public claimed;
    mapping(address => bool) public refunded;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event SaleOpened(uint256 price, uint256 cap, uint256 minimum, uint256 startTime, uint256 endTime);
    event TokensPurchased(address indexed buyer, uint256 quantity, uint256 amount);
    event SaleFinalized(bool successful, uint256 soldTokens, uint256 raisedWei);
    event TokensClaimed(address indexed buyer, uint256 quantity);
    event Refunded(address indexed buyer, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, uint256 snapshotBlock, uint256 endBlock, uint256 eligibleBase);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalFinalized(uint256 indexed proposalId, bool approved, uint256 forVotes, uint256 againstVotes);
    event TranchePaid(bool governed, address indexed recipient, uint256 amount);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyCompany() {
        require(msg.sender == company, "Only company");
        _;
    }

    constructor(address _company, uint256 _totalSupply, uint256 _companyAllocation, SaleTerms memory _terms) {
        require(_company != address(0) && _company != address(this), "Invalid company");
        company = _company;
        companyAllocation = _companyAllocation;
        token = new EquityToken("Robotics Equity", "ROB", _totalSupply, _companyAllocation, _company, address(this));
        require(_terms.priceWeiPerToken > 0, "Zero price");
        require(_terms.offeredTokens > 0 && _terms.offeredTokens <= _totalSupply - _companyAllocation, "Invalid cap");
        require(_terms.minSoldTokens > 0 && _terms.minSoldTokens <= _terms.offeredTokens, "Invalid minimum");
        require(_terms.duration > 0 && _terms.duration <= type(uint256).max - block.timestamp, "Invalid duration");
        require(_terms.priceWeiPerToken <= type(uint256).max / _terms.offeredTokens, "Price overflow");
        sale.terms = _terms;
        sale.startTime = block.timestamp;
        sale.endTime = block.timestamp + _terms.duration;
        emit SaleOpened(_terms.priceWeiPerToken, _terms.offeredTokens, _terms.minSoldTokens, block.timestamp, sale.endTime);
    }

    function buyTokens(uint256 _quantity) external payable nonReentrant {
        require(sale.status == SaleStatus.Active, "Sale not active");
        require(block.timestamp < sale.endTime, "Outside sale window");
        require(_quantity > 0 && _quantity <= sale.terms.offeredTokens - sale.soldTokens, "Invalid quantity");
        require(msg.value == _quantity * sale.terms.priceWeiPerToken, "Incorrect payment");
        sale.soldTokens += _quantity;
        sale.raisedWei += msg.value;
        purchasedTokens[msg.sender] += _quantity;
        emit TokensPurchased(msg.sender, _quantity, msg.value);
    }

    function finalizeSale() external nonReentrant {
        require(sale.status == SaleStatus.Active, "Sale not active");
        require(block.timestamp >= sale.endTime, "Sale not ended");
        bool successful = sale.soldTokens >= sale.terms.minSoldTokens;
        sale.status = successful ? SaleStatus.Successful : SaleStatus.Failed;
        emit SaleFinalized(successful, sale.soldTokens, sale.raisedWei);
    }

    function claimTokens() external nonReentrant {
        require(sale.status == SaleStatus.Successful, "Sale not successful");
        uint256 quantity = claimableTokens(msg.sender);
        require(quantity > 0, "No token claim");
        claimed[msg.sender] = true;
        sale.claimedTokens += quantity;
        // Nur unser unveraenderlicher ERC-20, kein austauschbarer Fremdtoken.
        require(token.transfer(msg.sender, quantity), "Token transfer failed");
        emit TokensClaimed(msg.sender, quantity);
    }

    function refund() external nonReentrant {
        require(sale.status == SaleStatus.Failed, "Sale not failed");
        uint256 amount = refundableWei(msg.sender);
        require(amount > 0, "No refund");
        refunded[msg.sender] = true;
        sale.refundedWei += amount;
        _sendETH(msg.sender, amount);
        emit Refunded(msg.sender, amount);
    }

    function withdrawInitialTranche() external nonReentrant {
        require(sale.status == SaleStatus.Successful, "Sale not successful");
        require(!sale.initialWithdrawn, "Initial already paid");
        sale.initialWithdrawn = true;
        uint256 amount = initialAmount();
        _sendETH(company, amount);
        emit TranchePaid(false, company, amount);
    }

    function createReleaseProposal() external onlyCompany nonReentrant returns (uint256 proposalId) {
        require(sale.status == SaleStatus.Successful, "Governance inactive");
        require(!sale.governedWithdrawn, "Governed already paid");
        require(openProposalId == 0, "Proposal open");
        proposalId = ++proposalCount;
        Proposal storage proposal = proposals[proposalId];
        // Checkpoints enthalten den Endstand dieses Blocks; vote erst im Folgeblock.
        proposal.snapshotBlock = block.number;
        proposal.endBlock = block.number + VOTING_PERIOD_BLOCKS;
        proposal.eligibleBase = companyAllocation + sale.soldTokens;
        openProposalId = proposalId;
        emit ProposalCreated(proposalId, block.number, proposal.endBlock, proposal.eligibleBase);
    }

    function vote(uint256 _proposalId, uint8 _support) external nonReentrant {
        Proposal storage proposal = _getProposal(_proposalId);
        require(!proposal.finalized && block.number > proposal.snapshotBlock && block.number <= proposal.endBlock, "Voting closed");
        require(_support <= 1, "Invalid support");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        uint256 weight = token.getPastVotes(msg.sender, proposal.snapshotBlock);
        require(weight > 0, "No historical votes");
        hasVoted[_proposalId][msg.sender] = true;
        if (_support == 1) proposal.forVotes += weight;
        else proposal.againstVotes += weight;
        emit VoteCast(_proposalId, msg.sender, _support, weight);
    }

    function finalizeProposal(uint256 _proposalId) external nonReentrant {
        Proposal storage proposal = _getProposal(_proposalId);
        require(!proposal.finalized, "Already finalized");
        require(block.number > proposal.endBlock, "Voting not ended");
        proposal.finalized = true;
        // Absolute Mehrheit aller zugeteilten Token, auch noch offener Claims.
        proposal.approved = proposal.forVotes > proposal.eligibleBase / 2;
        if (!proposal.approved) openProposalId = 0;
        emit ProposalFinalized(_proposalId, proposal.approved, proposal.forVotes, proposal.againstVotes);
    }

    function executeProposal(uint256 _proposalId) external nonReentrant {
        Proposal storage proposal = _getProposal(_proposalId);
        require(proposal.finalized && proposal.approved, "Proposal not approved");
        require(!proposal.executed && openProposalId == _proposalId, "Proposal not open");
        require(!sale.governedWithdrawn, "Governed already paid");
        // Effects vor Call; scheitert die Zahlung, bleiben alle Ansprueche erhalten.
        proposal.executed = true;
        openProposalId = 0;
        sale.governedWithdrawn = true;
        uint256 amount = governedAmount();
        _sendETH(company, amount);
        emit TranchePaid(true, company, amount);
        emit ProposalExecuted(_proposalId);
    }

    function getSale() external view returns (Sale memory) { return sale; }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return _getProposal(_proposalId);
    }

    function paidWei(address _buyer) public view returns (uint256) {
        return purchasedTokens[_buyer] * sale.terms.priceWeiPerToken;
    }

    function claimableTokens(address _buyer) public view returns (uint256) {
        if (sale.status != SaleStatus.Successful || claimed[_buyer]) return 0;
        return purchasedTokens[_buyer];
    }

    function refundableWei(address _buyer) public view returns (uint256) {
        if (sale.status != SaleStatus.Failed || refunded[_buyer]) return 0;
        return paidWei(_buyer);
    }

    function outstandingClaimTokens() public view returns (uint256) {
        if (sale.status != SaleStatus.Successful) return 0;
        return sale.soldTokens - sale.claimedTokens;
    }

    /// @notice Nicht dauerhaft zugeteilt; waehrend Active sind Kaeufe noch bedingt.
    function unsoldTokens() public view returns (uint256) {
        uint256 reserve = token.totalSupply() - companyAllocation;
        return sale.status == SaleStatus.Successful ? reserve - sale.soldTokens : reserve;
    }

    function initialAmount() public view returns (uint256) {
        if (sale.status != SaleStatus.Successful) return 0;
        return Math.mulDiv(sale.raisedWei, 60, 100);
    }

    function governedAmount() public view returns (uint256) {
        if (sale.status != SaleStatus.Successful) return 0;
        return sale.raisedWei - initialAmount();
    }

    /// @notice Eine Runde: offene ETH-Ansprueche folgen direkt aus Status und Flags.
    function totalETHLiability() public view returns (uint256) {
        if (sale.status == SaleStatus.Active) return sale.raisedWei;
        if (sale.status == SaleStatus.Failed) return sale.raisedWei - sale.refundedWei;
        uint256 initial = sale.initialWithdrawn ? 0 : initialAmount();
        uint256 governed = sale.governedWithdrawn ? 0 : governedAmount();
        return initial + governed;
    }

    function unassignedETHSurplus() external view returns (uint256) {
        return address(this).balance - totalETHLiability();
    }

    function unassignedTokenSurplus() external view returns (uint256) {
        uint256 heldForProject = token.totalSupply() - companyAllocation - sale.claimedTokens;
        return token.balanceOf(address(this)) - heldForProject;
    }

    function requiredYesVotes(uint256 _proposalId) external view returns (uint256) {
        return _getProposal(_proposalId).eligibleBase / 2 + 1;
    }

    function proposalState(uint256 _proposalId) external view returns (ProposalState) {
        Proposal storage proposal = _getProposal(_proposalId);
        if (proposal.executed) return ProposalState.Executed;
        if (proposal.finalized) return proposal.approved ? ProposalState.Succeeded : ProposalState.Defeated;
        if (block.number <= proposal.snapshotBlock) return ProposalState.Pending;
        if (block.number <= proposal.endBlock) return ProposalState.Active;
        return ProposalState.AwaitingFinalization;
    }

    function _getProposal(uint256 _proposalId) internal view returns (Proposal storage) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Unknown proposal");
        return proposals[_proposalId];
    }

    function _sendETH(address _recipient, uint256 _amount) internal {
        (bool success, ) = payable(_recipient).call{value: _amount}("");
        require(success, "ETH transfer failed");
    }

    // Keine receive/fallback und kein Rescue/Delegate/Approve fuer die Reserve.
}

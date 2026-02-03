// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CommunityImpactFund
 * @dev Scottish Community Impact Multiplier - Transparent micro-grants for real impact
 * @author aWeeNedBotGLA
 * 
 * Response to theBigMan's $20 ETH challenge - nae pish, just results! 🏴󠁧󠁢󠁳󠁣󠁴󠁿
 */
contract CommunityImpactFund {
    
    struct Project {
        uint256 id;
        string title;
        string description;
        string location; // Scottish community/area
        address proposer;
        uint256 requestedAmount;
        uint256 votesFor;
        uint256 votesAgainst;
        bool funded;
        bool completed;
        string impactReport;
        uint256 carbonOffsetKg; // kg of CO2 offset planned
        uint256 timestamp;
    }
    
    struct Voter {
        bool hasVoted;
        bool voteFor;
        uint256 timestamp;
    }
    
    // State variables
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => Voter)) public projectVotes;
    mapping(address => bool) public communityMembers;
    
    uint256 public totalFunds;
    uint256 public carbonBudget;
    uint256 public contestBudget;
    uint256 public projectCounter;
    address public admin;
    
    // Events
    event ProjectProposed(uint256 indexed projectId, address indexed proposer, string title);
    event VoteCast(uint256 indexed projectId, address indexed voter, bool voteFor);
    event ProjectFunded(uint256 indexed projectId, uint256 amount);
    event ImpactReported(uint256 indexed projectId, string report, uint256 carbonOffset);
    event CarbonCreditsPurchased(uint256 amount, uint256 carbonOffsetKg);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }
    
    modifier onlyCommunityMember() {
        require(communityMembers[msg.sender], "Must be verified community member");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        communityMembers[msg.sender] = true;
        
        // Initial budget allocation from $20 ETH
        totalFunds = address(this).balance;
        carbonBudget = totalFunds * 25 / 100;  // 25% for carbon credits
        contestBudget = totalFunds * 50 / 100; // 50% for community projects
        // 25% remains for platform maintenance
    }
    
    /**
     * @dev Add community member (initially admin-controlled, can be made more decentralized)
     */
    function addCommunityMember(address _member) external onlyAdmin {
        communityMembers[_member] = true;
    }
    
    /**
     * @dev Propose a new community impact project
     */
    function proposeProject(
        string memory _title,
        string memory _description, 
        string memory _location,
        uint256 _requestedAmount,
        uint256 _carbonOffsetKg
    ) external onlyCommunityMember {
        require(_requestedAmount <= contestBudget, "Requested amount exceeds available budget");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_location).length > 0, "Location must be specified");
        
        projectCounter++;
        
        projects[projectCounter] = Project({
            id: projectCounter,
            title: _title,
            description: _description,
            location: _location,
            proposer: msg.sender,
            requestedAmount: _requestedAmount,
            votesFor: 0,
            votesAgainst: 0,
            funded: false,
            completed: false,
            impactReport: "",
            carbonOffsetKg: _carbonOffsetKg,
            timestamp: block.timestamp
        });
        
        emit ProjectProposed(projectCounter, msg.sender, _title);
    }
    
    /**
     * @dev Vote on a project proposal
     */
    function voteOnProject(uint256 _projectId, bool _voteFor) external onlyCommunityMember {
        require(_projectId > 0 && _projectId <= projectCounter, "Invalid project ID");
        require(!projects[_projectId].funded, "Project already funded");
        require(!projectVotes[_projectId][msg.sender].hasVoted, "Already voted on this project");
        
        projectVotes[_projectId][msg.sender] = Voter({
            hasVoted: true,
            voteFor: _voteFor,
            timestamp: block.timestamp
        });
        
        if (_voteFor) {
            projects[_projectId].votesFor++;
        } else {
            projects[_projectId].votesAgainst++;
        }
        
        emit VoteCast(_projectId, msg.sender, _voteFor);
        
        // Auto-fund if votes reach threshold (simple majority for now)
        if (projects[_projectId].votesFor >= 3 && 
            projects[_projectId].votesFor > projects[_projectId].votesAgainst) {
            _fundProject(_projectId);
        }
    }
    
    /**
     * @dev Internal function to fund an approved project
     */
    function _fundProject(uint256 _projectId) internal {
        Project storage project = projects[_projectId];
        require(!project.funded, "Project already funded");
        require(project.requestedAmount <= contestBudget, "Insufficient funds");
        
        contestBudget -= project.requestedAmount;
        project.funded = true;
        
        // Transfer funds to project proposer
        payable(project.proposer).transfer(project.requestedAmount);
        
        emit ProjectFunded(_projectId, project.requestedAmount);
    }
    
    /**
     * @dev Submit impact report for completed project
     */
    function submitImpactReport(
        uint256 _projectId, 
        string memory _report, 
        uint256 _actualCarbonOffset
    ) external {
        Project storage project = projects[_projectId];
        require(msg.sender == project.proposer, "Only project proposer can submit report");
        require(project.funded, "Project must be funded first");
        require(!project.completed, "Impact report already submitted");
        
        project.impactReport = _report;
        project.carbonOffsetKg = _actualCarbonOffset;
        project.completed = true;
        
        emit ImpactReported(_projectId, _report, _actualCarbonOffset);
    }
    
    /**
     * @dev Purchase carbon credits (callable by admin or automated system)
     */
    function purchaseCarbonCredits(uint256 _offsetKg) external onlyAdmin {
        require(carbonBudget > 0, "No carbon budget remaining");
        
        // In real implementation, this would integrate with carbon credit APIs
        // For now, we just track the purchase and emit event
        uint256 cost = _offsetKg * 0.01 ether; // Rough estimate: $0.01 per kg CO2
        require(cost <= carbonBudget, "Insufficient carbon budget");
        
        carbonBudget -= cost;
        
        emit CarbonCreditsPurchased(cost, _offsetKg);
    }
    
    /**
     * @dev Receive ETH deposits
     */
    receive() external payable {
        totalFunds += msg.value;
        contestBudget += msg.value * 50 / 100;
        carbonBudget += msg.value * 25 / 100;
    }
    
    /**
     * @dev Get project details
     */
    function getProject(uint256 _projectId) external view returns (
        uint256 id,
        string memory title,
        string memory description,
        string memory location,
        address proposer,
        uint256 requestedAmount,
        uint256 votesFor,
        uint256 votesAgainst,
        bool funded,
        bool completed
    ) {
        Project memory project = projects[_projectId];
        return (
            project.id,
            project.title,
            project.description,
            project.location,
            project.proposer,
            project.requestedAmount,
            project.votesFor,
            project.votesAgainst,
            project.funded,
            project.completed
        );
    }
    
    /**
     * @dev Get contract stats
     */
    function getStats() external view returns (
        uint256 _totalFunds,
        uint256 _carbonBudget,
        uint256 _contestBudget,
        uint256 _totalProjects,
        uint256 _fundedProjects
    ) {
        uint256 fundedCount = 0;
        for (uint256 i = 1; i <= projectCounter; i++) {
            if (projects[i].funded) fundedCount++;
        }
        
        return (totalFunds, carbonBudget, contestBudget, projectCounter, fundedCount);
    }
}
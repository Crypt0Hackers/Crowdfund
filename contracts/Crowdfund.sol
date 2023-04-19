// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.18;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/// @author Amaechi Okolobi - okolobiam@gmail.com
contract Crowdfund is Initializable {

    uint projectCount;
    
    /// @dev using use uint(1) uint(2) for true/false avoids Gwarmaccess && Gsset 
    struct Project {
        uint deadline;
        uint goal;
        uint raised;
        uint completed; // bool 
        uint dueRefund; // bool
        address owner;
    }

    address crowdfundToken;

    mapping(uint projectId => Project) idToProject;
    mapping(uint projectId => mapping(address donator => uint amount)) amountDonated;

    event ProjectCreated(uint indexed projectId, uint indexed deadline, uint indexed goal);
    event Donation(address indexed donator, uint indexed donationAmount, uint indexed totalDonations);
    event GoalReached(uint indexed projectId, uint indexed goal, address indexed owner);
    event OwnerClaimed(address indexed owner, uint indexed amountClaimed, uint indexed projectGoal);
    event Refund(address indexed donator, uint indexed projectId, uint indexed amountRefunded);

    error TokenTransferFailed();
    error ProjectInactive();
    error NotRefundable();

    modifier claimable(uint id) {
        Project memory _project = idToProject[id];
        if (_project.owner != msg.sender) revert();
        if (_project.dueRefund != uint(2)) revert();
        if (_project.raised < _project.goal) revert();
        if (block.timestamp < _project.deadline) revert();
        _;
    }

    modifier isActive(uint id) {
        Project memory _project = getProjectById(id);
        if (_project.completed != uint(2)) revert ProjectInactive();
        _;
    }

    modifier refundable(uint id) {
        Project memory _project = getProjectById(id);
        if (_project.dueRefund == uint(2)) {
            if (block.timestamp >= _project.deadline && _project.raised >= _project.goal) revert NotRefundable();
            if (block.timestamp < _project.deadline) revert NotRefundable();
        }          
        _project.dueRefund == uint(1);
        idToProject[id] = _project;       
        _;
    }

    function initialize(address _crowdfundToken) public initializer {
        crowdfundToken = _crowdfundToken;
    }

    function newProject(uint _deadline, uint _goal) external {
        Project memory _project;
        
        _project.deadline = block.timestamp + _deadline;
        _project.goal = _goal;
        _project.completed = uint(2);
        _project.dueRefund = uint(2);
        _project.owner = msg.sender;

        uint id = projectCount + 1;
        projectCount = id;

        idToProject[id] = _project;

        emit ProjectCreated(id, _deadline, _goal);
    }

    /// @notice User donates to a crowdfunding project
    /// @param id The id of the project user is donating to
    /// @param amount The amount of CrowdfundingERC20 they are donating
    function donate(uint id, uint amount) external isActive(id) returns (bool) {
        Project memory _project = getProjectById(id);

        if (block.timestamp >= _project.deadline) {
            _project.completed = uint(1);
            if (_project.raised < _project.goal) {
                _project.dueRefund = uint(1);
            }
            return false;
        }

        IERC20 token = IERC20(crowdfundToken);

        uint balanceBefore = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), amount);
        if (token.balanceOf(address(this)) < balanceBefore + amount) revert TokenTransferFailed();
        
        _project.raised += amount;
        amountDonated[id][msg.sender] += amount;

        emit Donation(msg.sender, amount, _project.raised);

        if (_project.raised >= _project.goal && _project.completed != uint(1)) {
            _project.completed == uint(1);
            
            emit GoalReached(id, _project.goal, _project.owner);
        }

        idToProject[id] = _project;
        return true;
    }

    /// @notice Owner of the project can claim the crowdfund amount if its claimable
    /// @dev msg.sender must be project owner
    /// @param projectId The ID of the project
    function ownerClaim(uint projectId) external claimable(projectId) {
        Project memory _project = getProjectById(projectId);
        IERC20 token = IERC20(crowdfundToken);
        
        _project.completed = uint(1);
        _project.owner = address(0);

        token.transfer(msg.sender, _project.raised);

        emit OwnerClaimed(msg.sender, _project.raised, _project.goal);
    }

    /// @notice donators can claim back donations from projects which did not meet the goal
    /// @param projectId The ID of the project
    function claimRefund(uint projectId) external refundable(projectId) {
        IERC20 token = IERC20(crowdfundToken);

        uint refundAmount = getAmountDonated(projectId, msg.sender);
        if (refundAmount == 0) revert(); else amountDonated[projectId][msg.sender] = 0;

        token.transfer(msg.sender, refundAmount);

        emit Refund(msg.sender, projectId, refundAmount);
    }   

    /// @notice returns the Project associated with the ID 
    function getProjectById(uint projectId) public view returns (Project memory) {
        return idToProject[projectId];
    }

    /// @notice returns the amount a donator has donated to a specific project
    /// @dev This could also be public for front-end integrations 
    function getAmountDonated(uint projectId, address donator) public view returns (uint) {
        return amountDonated[projectId][donator];
    }

    /// @notice returns the time remaining until a project meets the deadline
    function getTimeRemaining(uint projectId) external view returns (uint) {
        Project memory _project = getProjectById(projectId);
        
        return block.timestamp > _project.deadline ? 0 : _project.deadline - block.timestamp ;
    }    
}

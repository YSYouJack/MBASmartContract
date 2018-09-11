pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./DateTimeUtility.sol";
import "./DaicoToken.sol";

/**
 * @title MBAFund
 * @dev The DAICO managed fund.
 */
contract MBAFund is Ownable {
	using SafeMath for uint256;
	using DateTimeUtility for uint256;
	
    // The fund state.
	enum State {
	    NotReady       // The fund is not ready for any operations.
	    , TeamWithdraw // The fund can be withdrawn and voting ballots.
	    , Refunding    // The fund only can be refund..
	    , Closed       // The fund is closed.
	}

	// @dev Ballot types.
	enum BallotType { 
	    Tap          // Tap ballot.
	    , Refund     // Refund ballot.
	}
	
	// A special number indicates that no valid id.
	uint256 NON_UINT256 = (2 ** 256) - 1;
	
	// Data type represent a vote.
	struct Vote {
		address tokeHolder; // Voter address.
		bool inSupport;     // Support or not.
	}
	
	// A ballot.
	struct Ballot {              
	    BallotType ballotType;     // Ballot type.
	    uint256 openingTime;       // Opening time of the voting.
	    uint256 closingTime;       // Closing time of the voting.
	    Vote[] votes;              // All votes.
		mapping (address => bool) voted; // Prevent duplicate vote.
		bool isPassed;             // Final result.
		bool isFinialized;         // Ballot state.
		uint256 targetWei;         // Tap ballot target.
	}
	
	// Budget plan stands a budget period for the team to withdraw the funds.
	struct BudgetPlan {
	    uint256 ballotId;         // The tap ballot id.
	    uint256 budgetInWei;      // Budget in wei.
	    uint256 withdrawnWei;     // Withdrawn wei.
	    uint256 startTime;        // Start time of this budget plan. 
	    uint256 endTime;          // End time of this budget plan.
	}
	
	// Team wallet to receive the budget.
	address public teamWallet;
	
	// Fund state.
	State public state;
	
	// Daico Token.
	DaicoToken public token;
	
	// Ballot history.
	Ballot[] public ballots;
	
	// Budget plan history.
	BudgetPlan[] public budgetPlans;
	
	// Current budget plan id.
	uint256 currentBudgetPlanId;
	
	// Propotion of yes to pass a tap ballot in %.
	uint256 PROPOTION_YES_TAP = 50;
	
	// Propotion of yes to pass a refund ballot in %.
	uint256 PROPOTION_YES_REFUND = 70;
	
	// The mininum budget.
	uint256 public MIN_WITHDRAW_WEI = 1 ether;
	
	// The fist withdraw rate when the crowdsale was successed.
	uint256 public FIRST_WITHDRAW_RATE = 30;
	
	// The voting duration.
	uint256 public VOTING_DURATION = 1 weeks;
	
	// Refund lock duration.
	uint256 public REFUND_LOCK_DURATION = 30 days;
	
	// Refund lock date.
	uint256 public refundLockDate = 0;
	
	event TeamWithdrawEnabled();
	event RefundsEnabled();
	event Closed();
	
	event Voted(address indexed voter, bool isSupported);
	event BallotAdded(uint256 openingTime, uint256 closingTime, uint256 targetWei, BallotType ballotType);
	event BallotClosed(uint256 id, BallotType ballotType, bool isPassed);
	
	event Withdrew(uint256 weiAmount);
	event Refund(address indexed holder, uint256 amount);
	
	modifier onlyTokenHolders {
		require(token.balanceOf(msg.sender) != 0);
		_;
	}
	
	modifier inWithdrawState {
	    require(state == State.TeamWithdraw);
	    _;
	}
	
	/**
	 * @param _teamWallet The wallet which receives the funds.
	 * @param _token Daico token address.
	 */
    constructor(address _teamWallet, address _token) public {
		require(_teamWallet != address(0));
		require(_token != address(0));
		
		teamWallet = _teamWallet;
		state = State.NotReady;
		token = DaicoToken(_token);
	}
	
	/**
	 * @dev Enable the TeamWithdraw state.
	 */
	function enableTeamWithdraw() onlyOwner public {
		require(state == State.NotReady);
		state = State.TeamWithdraw;
		emit TeamWithdrawEnabled();
		
		budgetPlans.length++;
		BudgetPlan storage plan = budgetPlans[0];
		
	    plan.ballotId = NON_UINT256;
	    plan.budgetInWei = address(this).balance.mul(FIRST_WITHDRAW_RATE).div(100);
	    plan.withdrawnWei = 0;
	    plan.startTime = now;
	    plan.endTime = _budgetEndTime(now);
	    
	    currentBudgetPlanId = 0;
	}
	
	/**
	 * @dev Close the fund.
	 */
	function close() onlyOwner inWithdrawState public {
	    require(address(this).balance < MIN_WITHDRAW_WEI);
	    
		state = State.Closed;
		emit Closed();
		
		teamWallet.transfer(address(this).balance);
	}
	
	/**
	 * @dev Check if there is an ongoing ballot.
	 */
	function isThereAnOnGoingBallot() public view returns (bool) {
	    if (ballots.length == 0 || state != State.TeamWithdraw) {
	        return false;
	    } else {
	        Ballot storage p = ballots[ballots.length - 1];
	        return now >= p.openingTime && now <= p.closingTime;
	    }
	}
	
	/**
	 * @dev Check if next budget period plan has been made.
	 */
	function isNextBudgetPlanMade() public view returns (bool) {
	    if (state != State.TeamWithdraw) {
	        return false;
	    } else {
	        return currentBudgetPlanId != budgetPlans.length - 1;
	    }
	}
	
	/**
	 * @dev Get number of ballots. 
	 */
	function numberOfBallots() public view returns (uint256) {
	    return ballots.length;
	}
	
	/**
	 * @dev Get number of budget plans. 
	 */
	function numberOfBudgetPlan() public view returns (uint256) {
	    return budgetPlans.length;
	}
	
	/**
	 * @dev Try to finialize the last ballot.
	 */
	function tryFinializeLastBallot() inWithdrawState public {
	    if (ballots.length == 0) {
	        return;
	    }
	    
	    uint256 id = ballots.length - 1;
	    Ballot storage p = ballots[id];
	    
	    uint256 propotion = (p.ballotType == BallotType.Tap) 
	        ? PROPOTION_YES_TAP : PROPOTION_YES_REFUND;
	    
	    if (now > p.closingTime && !p.isFinialized) {
	        p.isPassed = _countVotes(p, propotion);
	        p.isFinialized = true;
	        
	        emit BallotClosed(id, p.ballotType, p.isPassed);
	        
	        if (p.isPassed) {
	            if (p.ballotType == BallotType.Refund) {
	                _enableRefunds();
	            } else {
	                _makeBudgetPlan(p, id);
	            }
	        }
	    }
	}
	
	/**
	 * @dev Create new tap ballot.
	 * @param _targetWei The voting target.
	 * @param _startTime Start time of ballot.
	 */
	function newTapBallot(uint256 _targetWei, uint256 _startTime) 
	    onlyOwner 
	    inWithdrawState 
	    public
	{
	    // Check the last result.
	    tryFinializeLastBallot();
	    require(state == State.TeamWithdraw);
	    
	    // Ballot is disable when the budget plan has been made.
	    require(!isNextBudgetPlanMade());
	    
	    // Ballot voting is exclusive.
	    require(!isThereAnOnGoingBallot());
		
		// The minimum wei requirement.
		require(_targetWei >= MIN_WITHDRAW_WEI && _targetWei <= address(this).balance);
	    
	    uint256 id = ballots.length++;
        Ballot storage p = ballots[id];
        p.ballotType = BallotType.Tap;
		p.openingTime = _startTime;
		p.closingTime = p.openingTime + VOTING_DURATION - 1;
		p.isPassed = false;
		p.isFinialized = false;
		p.targetWei = _targetWei;
		
		emit BallotAdded(p.openingTime
			, p.closingTime
			, p.targetWei
			, p.ballotType);
	}
	
	/**
	 * @dev Create a refund ballot.
	 * @param _startTime Start time of ballot.
	 */
	function newRefundBallot(uint256 _startTime) onlyOwner inWithdrawState public {
	    // Check the last result.
	    tryFinializeLastBallot();
	    require(state == State.TeamWithdraw);
	    
	    // Ballot voting is exclusive.
	    require(!isThereAnOnGoingBallot());
	    
	    // Create ballots.
		uint256 id = ballots.length++;
		Ballot storage p = ballots[id];
		p.ballotType = BallotType.Refund;
		p.openingTime = _startTime;
		p.closingTime = p.openingTime + VOTING_DURATION - 1;
		p.isPassed = false;
		p.isFinialized = false;
		
		// Signal the event.
		emit BallotAdded(p.openingTime, p.closingTime, 0, p.ballotType);
	}
	
	/**
	 * @dev Vote for an ongoing ballot.
	 * @param _supportsBallot True if the vote supports the ballot.
	 */
	function vote(bool _supportsBallot) onlyTokenHolders inWithdrawState public
	{
	    // Check the last result.
	    require(isThereAnOnGoingBallot());
		
		// Check the ongoing ballot's type and reject the voted voters.
		Ballot storage p = ballots[ballots.length - 1];
		require(true != p.voted[msg.sender]);
		
		// Record the vote.
		uint256 voteId = p.votes.length++;
		p.votes[voteId].tokeHolder = msg.sender;
		p.votes[voteId].inSupport = _supportsBallot;
		p.voted[msg.sender] = true;
		
		// Signal the event.
		emit Voted(msg.sender, _supportsBallot);
	}
	
	/**
	 * @dev Withdraw the wei to team wallet.
	 * @param _amount Withdraw wei.
	 */
	function withdraw(uint256 _amount) onlyOwner inWithdrawState public {
	    // Check the last result.
	    tryFinializeLastBallot();
	    require(state == State.TeamWithdraw);
	    
	    // Try to update the budget plans.
	    BudgetPlan storage currentPlan = budgetPlans[currentBudgetPlanId];
	    if (now > currentPlan.endTime) {
	        require(isNextBudgetPlanMade());
	        ++currentBudgetPlanId;
	    }
	    
	    // Withdraw the weis.
	    _withdraw(_amount);
	}
	
	/**
     * @dev Tokenholders can claim refunds here.
     */
	function claimRefund() onlyTokenHolders public {
	    // Check the state.
		require(state == State.Refunding);
		
		// Validate the time.
		require(now > refundLockDate + REFUND_LOCK_DURATION);
		
		// Calculate the transfering wei. 
		uint256 amount = address(this).balance.mul(token.balanceOf(msg.sender)).div(token.totalSupply());
		
		// Burn all the token of the refunder.
		token.burnFromDaico(msg.sender);
		
		// Transfer the refends.
		msg.sender.transfer(amount);
	}
	
	/**
	 * @dev Check if refund is in lock period.
	 */
	 function isRefundLocked() public view returns (bool) {
	     return state == State.Refunding && now < refundLockDate + REFUND_LOCK_DURATION;
	 }
	
	/**
     * @dev Receive the initial funds from crowdsale contract.
     */
	function receiveInitialFunds() payable public {
	    require(state == State.NotReady);
	}
	
	/**
     * @dev Fallback function to receive initial funds.
     */
	function () payable public {
	    receiveInitialFunds();
	}
	
	function _withdraw(uint256 _amount) internal {
	    BudgetPlan storage plan = budgetPlans[currentBudgetPlanId];
	    
	    // Validate the time.
	    require(now <= plan.endTime);
	    
	    // Check the remaining wei.
	    require(_amount + plan.withdrawnWei <= plan.budgetInWei);
	       
	    // Transfer the wei.
	    plan.withdrawnWei += _amount;
	    teamWallet.transfer(_amount);
	    
	    // Signal the event.
	    emit Withdrew(_amount);
	}
	
	function _countVotes(Ballot storage p, uint256 propotion)
	    view
	    internal 
	    returns (bool)
	{
		uint256 yes = 0;
		uint256 total = 0;
		
		for (uint256 i = 0; i < p.votes.length; ++i) {
			Vote storage v = p.votes[i];
			uint256 voteWeight = token.balanceOf(v.tokeHolder);
			if (v.inSupport) {
				yes += voteWeight;
			}
			
			total += voteWeight;
		}
		
		return yes.mul(100) > total.mul(propotion);
	}
	
	function _enableRefunds() inWithdrawState internal {
	    state = State.Refunding;
		emit RefundsEnabled();
		
		refundLockDate = now;
	}
	
	function _makeBudgetPlan(Ballot storage p, uint256 ballotId) 
	    internal
	{
	    require(p.ballotType != BallotType.Refund);
	    require(p.isFinialized);
	    require(p.isPassed);
	    require(!isNextBudgetPlanMade());
	    
	    uint256 planId = budgetPlans.length++;
	    BudgetPlan storage plan = budgetPlans[planId];
	    plan.ballotId = ballotId;
	    plan.budgetInWei = p.targetWei;
	    plan.withdrawnWei = 0;
	    
	    if (now > budgetPlans[currentBudgetPlanId].endTime && now <= budgetPlans[currentBudgetPlanId].startTime) {
	        plan.startTime = now;
	        plan.endTime = _budgetEndTime(now);
	        ++currentBudgetPlanId;
	    } else {
	        (plan.startTime, plan.endTime) = _nextBudgetTimes();
	    }
	}
	
	function _budgetEndTime(uint256 _startTime)
	    pure
	    internal
	    returns (uint256)
	{
	    // Decompose to datetime.
        uint32 year;
        uint8 month;
        uint8 mday;
        uint8 hour;
        uint8 minute;
        uint8 second;
        (year, month, mday, hour, minute, second) = _startTime.toGMT();
        
        // Calculate the next end time of budget period.
        month = ((month - 1) / 3 + 1) * 3 + 1;
        if (month > 12) {
            month -= 12;
            year += 1;
        }
        
        mday = 1;
        hour = 0;
        minute = 0;
        second = 0;
        
        uint256 end = DateTimeUtility.toUnixtime(year, month, mday, hour, minute, second) - 1;
        
        return end;
	}
    
    function _nextBudgetTimes() 
        view 
        internal 
        returns (uint256, uint256)
    {
        // Decompose to datetime.
        uint32 year;
        uint8 month;
        uint8 mday;
        uint8 hour;
        uint8 minute;
        uint8 second;
        (year, month, mday, hour, minute, second) = now.toGMT();
        
        // Calculate the next start time of budget period. (1/1, 4/1, 7/1, 10/1)
        month = ((month - 1) / 3 + 1) * 3 + 1;
        if (month > 12) {
            month -= 12;
            year += 1;
        }
        
        mday = 1;
        hour = 0;
        minute = 0;
        second = 0;
        
        uint256 start = DateTimeUtility.toUnixtime(year, month, mday, hour, minute, second);
        
        // Calculate the next end time of budget period.
        month = ((month - 1) / 3 + 1) * 3 + 1;
        if (month > 12) {
            month -= 12;
            year += 1;
        }
        
        uint256 end = DateTimeUtility.toUnixtime(year, month, mday, hour, minute, second) - 1;
        
        return (start, end);
    }
}
pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract Terminable is Ownable {
    bool isTerminated = false;
    
    event Terminated();
    
    modifier whenLive() {
        require(!isTerminated);
        _;
    }
    
    function terminate() onlyOwner whenLive public {
        isTerminated = true;
        emit Terminated();
    }
}

contract MBACC is StandardToken, Terminable {
	using SafeERC20 for ERC20;
	using SafeMath for uint256;
	
	string public name = "MBACC";
	string public symbol = "MBA";
	uint8 public decimals = 18;

    mapping (address => bool) issued;
    uint256 public eachIssuedAmount;
	
	constructor(uint256 _totalSupply, uint256 _eachIssuedAmount) public {
	    require(_totalSupply >= _eachIssuedAmount);
	    
		totalSupply_ = _totalSupply * (10 ** uint256(decimals));
		eachIssuedAmount = _eachIssuedAmount * (10 ** uint256(decimals));
		
		balances[msg.sender] = totalSupply_;
		issued[msg.sender] = true;
	}
	
	function issue() whenLive public {
	    require(balances[owner] >= eachIssuedAmount);
	    require(!issued[msg.sender]);
	    
	    balances[owner] = balances[owner].sub(eachIssuedAmount);
	    balances[msg.sender] = balances[msg.sender].add(eachIssuedAmount);
	    issued[msg.sender] = true;
	    
	    emit Transfer(owner, msg.sender, eachIssuedAmount);
	}
	
	function transfer(address _to, uint256 _value) whenLive public returns (bool) {
        return super.transfer(_to, _value);
    }
    
    function transferFrom(address _from, address _to, uint256 _value)
        whenLive
        public
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) 
        whenLive 
        public 
        returns (bool)
    {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue)
        whenLive
        public
        returns (bool)
    {
        return super.increaseApproval(_spender, _addedValue);
    }
    
    function decreaseApproval(address _spender, uint _subtractedValue)
        whenLive
        public
        returns (bool)
    {
        return super.decreaseApproval(_spender, _subtractedValue);
    }
}

contract MBA is StandardToken {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    
    string public name = "MBA";
	string public symbol = "MBA";
	uint8 public decimals = 18;
	
	MBACC public ccToken;
	mapping (address => bool) public hasTranferedFromMBACC;
	
	constructor(uint256 _totalSupply, MBACC _token) public {
	    require(_token != address(0));
	    
		totalSupply_ = _totalSupply * (10 ** uint256(decimals));
		require(totalSupply_ >= _token.totalSupply());
		
		ccToken = _token;
		address(ccToken).delegatecall(bytes4(keccak256("terminate()")));
		
		if (_shouldTransferedFromMBACC(msg.sender)) {
	        _transferFromMBACCToMBA(msg.sender);
	    }
		
		uint256 remaining = totalSupply_.sub(ccToken.totalSupply());
		balances[msg.sender] = balances[msg.sender].add(remaining);
	}
	
	function balanceOf(address who) public view returns (uint256) {
	    if (hasTranferedFromMBACC[who]) {
	        return balances[who];
	    } else {
	        return balances[who].add(ccToken.balanceOf(who));
	    }
	}
	
	function transfer(address to, uint256 value) public returns (bool) {
	    if (_shouldTransferedFromMBACC(msg.sender)) {
	        _transferFromMBACCToMBA(msg.sender);
	    }
	    
	    if (_shouldTransferedFromMBACC(to)) {
	         _transferFromMBACCToMBA(to);
	    }
	    
	    return super.transfer(to, value);
	}
	
	function transferFrom(address from, address to, uint256 value) public returns (bool) {
	    if (_shouldTransferedFromMBACC(from)) {
	        _transferFromMBACCToMBA(from);
	    }
	    
	    if (_shouldTransferedFromMBACC(to)) {
	         _transferFromMBACCToMBA(to);
	    }
	    
	    return super.transferFrom(from, to, value);
	}
	
	function _shouldTransferedFromMBACC(address who) internal view returns (bool) {
	    return !hasTranferedFromMBACC[who] && (0 != ccToken.balanceOf(who));
	}
	
	function _transferFromMBACCToMBA(address who) internal {
	    require(balances[who] == 0);
	    require(hasTranferedFromMBACC[who] == false);
	    
	    hasTranferedFromMBACC[who] = true;
	    balances[who] = ccToken.balanceOf(who);
	} 
}
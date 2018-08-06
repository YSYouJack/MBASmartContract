pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract Terminable is Ownable {
    bool public isTerminated = false;
    
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
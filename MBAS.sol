pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "./Terminable.sol";

contract MBAS is StandardToken, Terminable {
	using SafeERC20 for ERC20;
	using SafeMath for uint256;
	
	string public name = "MBAS";
	string public symbol = "MBAS";
	uint8 public decimals = 18;
	
	constructor(uint256 _totalSupply) public {
		totalSupply_ = _totalSupply * (10 ** uint256(decimals));
		balances[msg.sender] = totalSupply_;
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
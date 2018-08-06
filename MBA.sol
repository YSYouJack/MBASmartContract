pragma solidity ^0.4.24;

import "./DaicoToken.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract MBA is StandardToken, DaicoToken, DetailedERC20 {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
	
	mapping (address => bool) public hasTranferedFromMBACC;
	
	ERC20 public ccToken;
	uint256 public INITIAL_SUPPLY = 4000000000;
	
	constructor(ERC20 _token) 
	    DetailedERC20("MBA", "MBA", 18)
	    public
	{
	    require(_token != address(0));
	    
		totalSupply_ = INITIAL_SUPPLY * (10 ** uint256(decimals));
		require(totalSupply_ >= _token.totalSupply());
		
		ccToken = _token;
		
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
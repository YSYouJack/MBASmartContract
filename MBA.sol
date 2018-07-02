pragma solidity ^0.4.24;

import "./MBACC.sol";

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
pragma solidity ^0.4.24;

import "./DaicoToken.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "./Terminable.sol";

/**
 * @title MBA.
 * @dev A final token for Mamba ICO which replaces MBACC and MBAS token. It 
 *      supports DAICO refunding. 
 */
contract MBA is StandardToken, DaicoToken, DetailedERC20 {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
	
	// Auto tranfering the balances of MBACC and MBAS to this token.
	mapping (address => bool) public hasTranfered;
	
	ERC20 public mbaccToken; 
	ERC20 public mbasToken;
	
	// Company wallet.
	address public companyWallet;
	
	// ICO token amount.
	uint256 public icoAmount = 0;
	
	// Initial supply without decimals.
	uint256 public INITIAL_SUPPLY = 4000000000;
	
	/**
	 * @param _mbaccToken MBACC token.
	 * @param _mbasToken MBAS token.
	 * @param _companyWallet Company wallet.
	 */
	constructor(ERC20 _mbaccToken, ERC20 _mbasToken, address _companyWallet) 
	    DetailedERC20("MBA", "MBA", 18)
	    public
	{
	    // Check the state of MBACC and MBAS.
	    require(_mbaccToken != address(0));
	    require(_mbasToken != address(0));
	    require(Terminable(_mbaccToken).isTerminated());
	    require(Terminable(_mbasToken).isTerminated());
	    require(_companyWallet != address(0));
	    
	    // Assign tokens.
	    mbaccToken = _mbaccToken;
	    mbasToken = _mbasToken;
	    
	    // Assign total supply.
		totalSupply_ = INITIAL_SUPPLY * (10 ** uint256(decimals));
		
		// Calculate ICO amount.
		icoAmount = totalSupply_.mul(65).div(100)
		          + mbaccToken.balanceOf(msg.sender)
		          + mbasToken.balanceOf(msg.sender);
		
		// Transfer to company wallet.
		companyWallet = _companyWallet;
		balances[companyWallet] = totalSupply_.mul(16).div(100);
		
		// Transfer the owner's token.
		_tryTransfered(msg.sender);
		
		// Add all token to owner.
		balances[msg.sender] = balances[msg.sender].add(
		    totalSupply_.mul(65).div(100));
	}
	
	function balanceOf(address who) public view returns (uint256) {
	    if (hasTranfered[who]) {
	        return balances[who];
	    } else {
	        return balances[who].add(mbaccToken.balanceOf(who))
	                .add(mbasToken.balanceOf(who));
	    }
	}
	
	function transfer(address to, uint256 value) public returns (bool) {
	    _tryTransfered(msg.sender);
	    _tryTransfered(to);
	    
	    return super.transfer(to, value);
	}
	
	function transferFrom(address from, address to, uint256 value) public returns (bool) {
	    _tryTransfered(from);
	    _tryTransfered(to);
	    
	    return super.transferFrom(from, to, value);
	}
	
	function _tryTransfered(address _who) internal {
	    if (!hasTranfered[_who]) {
	        hasTranfered[_who] = true;
	        if (0 != mbaccToken.balanceOf(_who)) {
	            balances[_who] = balances[_who].add(mbaccToken.balanceOf(_who));
	        }
	        
	        if (0 != mbasToken.balanceOf(_who)) {
	            balances[_who] = balances[_who].add(mbasToken.balanceOf(_who));
	        }
	    }
	}
}
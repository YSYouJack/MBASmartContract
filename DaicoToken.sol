pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title DaicoToken interface
 */
contract DaicoToken is BurnableToken, Ownable {
    using SafeERC20 for ERC20;
    
    address public daicoManager;
    
    event DaicoManagerSet(address indexed manager);
    
    modifier onlyDaicoManager () {
        require(daicoManager == msg.sender);
		_;
    }
    
     /**
	 * @dev Set the daico manager address.
	 * @param _daicoManager The manager address.
	 */
    function setDaicoManager(address _daicoManager) onlyOwner public {
        require(address(0) != _daicoManager);
        require(address(this) != _daicoManager);
        
        daicoManager = _daicoManager;
        emit DaicoManagerSet(daicoManager);
    } 
    
    /**
	 * @dev The DAICO fund contract calls this function to burn the user's token
	 * to avoid over refund.
	 * @param _from The address which just took its refund.
	 */
	function burnFromDaico(address _from) onlyDaicoManager external {
	    require(0 != balances[_from]);
	    _burn(_from, balances[_from]);
	}
}
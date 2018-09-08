pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";


/**
 * @title MBARefundVault
 * @dev This contract is modified from openzeppelin-solidity RefundVault.sol. 
 *      We change the refund function to be called from owner instead of investor.
 */
contract MBARefundVault is Ownable {
    using SafeMath for uint256;
    
    enum State { Active, Refunding, Closed }
    
    struct Investor {
        address wallet;
        uint256 deposited;
        bool isRefunded;
    }
    
    mapping (address => bool) public isInvested;
    mapping (address => uint256) public investorMap;
    Investor[] public investors;
  
    address public wallet;
    State public state;

    event Closed();
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);

    /**
     * @param _wallet Vault address
     */
    constructor(address _wallet) public {
        require(_wallet != address(0));
        wallet = _wallet;
        state = State.Active;
    }

    /**
     * @param investor Investor address
     */
    function deposit(address investor) onlyOwner public payable {
        require(state == State.Active);
        require(0 < msg.value);
        
        if (isInvested[investor]) {
            Investor storage p0 = investors[investorMap[investor]];
            p0.deposited = p0.deposited.add(msg.value);
        } else {
            uint256 id = investors.length++;
            investorMap[investor] = id;
            isInvested[investor] = true;
            
		    Investor storage p1 = investors[id];
		    p1.deposited = msg.value;
		    p1.isRefunded = false;
		    p1.wallet = investor;
        }
    }

    function close() onlyOwner public {
        require(state == State.Active);
        state = State.Closed;
        emit Closed();
        wallet.transfer(address(this).balance);
    }

    function enableRefunds() onlyOwner public {
        require(state == State.Active);
        state = State.Refunding;
        emit RefundsEnabled();
    }

    /**
     * @param _investor The investor addres.
     */
    function refund(address _investor) onlyOwner public {
        require(state == State.Refunding);
        require(isInvested[_investor]);
        
        Investor storage p = investors[investorMap[_investor]];
        require(!p.isRefunded);
        
        p.isRefunded = true;
        
        uint256 txFee = p.deposited.div(200); // 0.5% tx fee.
        if (0 != txFee) {
            wallet.transfer(txFee);
        }
        
        uint256 refundValue = p.deposited - txFee;
        if (0 != refundValue) {
            p.wallet.transfer(refundValue);
            emit Refunded(p.wallet, refundValue);
        }
    }
    
    /**
     * @dev Get investors count.
     */
    function investorsCount() public view returns (uint256) {
        return investors.length;
    }
}

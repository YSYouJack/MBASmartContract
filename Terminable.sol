pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";

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
pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "./MBARefundVault.sol";

/**
 * @title MBACrowdsale
 * @dev Crowdsale with soft cap, hard cap, and two bonus time window. Investors 
 * can get a refund if the soft cap in not met. 
 * Uses a RefundVault as the crowdsale's vault.
 * We use a fixed exchange rate from USD to Token, so the exchange rate between
 * ETH and Token is floating. 
 */
contract MBACrowdsale is TimedCrowdsale, Ownable {
    using SafeMath for uint256;
    
    // Soft cap and hard cap in distributed token.
    uint256 public softCapInToken;
    uint256 public hardCapInToken;
    uint256 public soldToken = 0;
    
    // Mininum contribute: 100 USD.
    uint256 public mininumContributeUSD = 100;
   
   // The mininum purchase token quantity.
    uint256 public mininumPurchaseTokenQuantity;
    
    // The calculated mininum contribute Wei.
    uint256 public mininumContributeWei;
    
    // The exchange rate from USD to Token.
    // 1 USD => 100 Token (0.005 USD => 1 Token).
    uint256 public exchangeRateUSDToToken = 200;
    
    // The bonus token thresold.
    uint256 public tokenFor1000Usd;
    uint256 public tokenFor5000Usd;
    uint256 public tokenFor10000Usd;
    
    // Refund vault used to hold funds while crowdsale is running
    MBARefundVault public vault;
    
    // Check if the crowdsale is finalized.
    bool public isFinalized = false;
    
    // Event 
    event Finalized();
    
    // Modifier
    modifier onlyNotFinailized() {
        require(!isFinalized);
        _;
    }
    
    /**
     * @param _softCapInUSD Minimal funds to be collected.
     * @param _hardCapInUSD Maximal funds to be collected.
     * @param _fund The Mamba DAICO fund contract address.
     * @param _token Mamba ERC20 contract.
     * @param _openingTime The opening time of crowdsale.
     * @param _closingTime The closing time of crowdsale.
     */
    constructor(uint256 _softCapInUSD
        , uint256 _hardCapInUSD
        , address _fund
        , ERC20 _token
        , uint256 _openingTime
        , uint256 _closingTime)
        Crowdsale(1, _fund, _token)
        TimedCrowdsale(_openingTime, _closingTime)
        public 
    {
        // Get the detailed erc20.
        DetailedERC20 erc20Token = DetailedERC20(token);
        
        // Set soft cap and hard cap.
        require(_softCapInUSD > 0 && _softCapInUSD <= _hardCapInUSD);
        
        softCapInToken = _softCapInUSD * exchangeRateUSDToToken * (10 ** uint256(erc20Token.decimals()));
        hardCapInToken = _hardCapInUSD * exchangeRateUSDToToken * (10 ** uint256(erc20Token.decimals()));
        
        require(erc20Token.balanceOf(owner) >= hardCapInToken);
        
        // Set bouns thresold.
        tokenFor1000Usd = 1000 * exchangeRateUSDToToken * (10 ** uint256(erc20Token.decimals()));
        tokenFor5000Usd = tokenFor1000Usd.mul(5);
        tokenFor10000Usd = tokenFor5000Usd.mul(2);
        
        // Create the refund vault.
        vault = new MBARefundVault(_fund);
        
        // Calculate mininum purchase token.
        mininumPurchaseTokenQuantity = exchangeRateUSDToToken * mininumContributeUSD 
           * (10 ** (uint256(erc20Token.decimals())));
           
        // Default rate 1 ether => 250 usd.
        uint256 _rate = 250 * exchangeRateUSDToToken * (10 ** (uint256(erc20Token.decimals()) - 18));
        uint256 minWei = mininumPurchaseTokenQuantity.div(_rate);
        if (minWei.mul(_rate) < mininumPurchaseTokenQuantity) {
            minWei += 1;
        }
        
        setRate(_rate, minWei);
    }
    
    /**
     * @dev Set the exchange rate from wei to token.
     * @param _rate The exchange rate.
     * @param _minWei The mininum contribution wei.
     */
    function setRate(uint256 _rate, uint256 _minWei) onlyOwner public {
        require(_minWei >= 1);
        require(_rate.mul(_minWei) >= mininumPurchaseTokenQuantity);
        require(_rate.mul(_minWei - 1) < mininumPurchaseTokenQuantity);
        
        mininumContributeWei = _minWei;
		rate = _rate;
    }
    
    /**
     * @dev Refund to the investors.
     * @param _investor Investor address.
     */
    function refund(address _investor) onlyOwner public {
        require(isFinalized);
        require(!softCapReached());

        vault.refund(_investor);
    }
    
    /**
     * @dev Get investor count.
     */
    function investorsCount() public view returns (uint256) {
        return vault.investorsCount();
    }
    
    /**
     * @dev Checks whether funding goal was reached.
     * @return Whether funding goal was reached
     */
    function softCapReached() public view returns (bool) {
        return soldToken >= softCapInToken;
    }
    
    /**
     * @dev Validate if crowdsale has started.
     */
    function hasStarted() view public returns (bool) {
        return now >= openingTime;
    }
    
    /**
     * @dev Send tokens to buyers using BTC or LTC.
     * @param _buyerWallet Buyer's wallet address.
     * @param _amount Amount of token to transfer.
     */
    function sendTokenToBuyer(address _buyerWallet, uint256 _amount) 
        public 
        onlyOwner
        onlyWhileOpen
        onlyNotFinailized
    {
        require(address(0) != _buyerWallet);
        require(address(this) != _buyerWallet);
        require(owner != _buyerWallet);
        
        // Add soldtoken to calculate sold token amount.
        soldToken = soldToken.add(_amount);
        require(soldToken <= hardCapInToken);
        
        // Calculate the bonus.
        _amount = _addBonus(_amount);
        
        // Transfer the token.
        token.transfer(_buyerWallet, _amount);
        
        // Emit the event.
        emit TokenPurchase(_buyerWallet, _buyerWallet, 0, _amount);
    }
    
    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization
     * work. Calls the contract's finalization function.
     */
    function finalize() onlyOwner public {
        require(!isFinalized);
        require(hasClosed() || token.balanceOf(address(this)) == 0 || soldToken == hardCapInToken);
        
        // Check if the crowdsale is successed.
        if (softCapReached()) {
            // Burn half of the unsold token.
            BurnableToken burnableToken = BurnableToken(token);
            burnableToken.burn(token.balanceOf(address(this)).div(2));
            
            // Transfer the rest token to owner.
            token.transfer(owner, token.balanceOf(address(this)));
            
            // Close the fund vault.   
            vault.close();
        } else {
            vault.enableRefunds();
        }
        
        // Emit the event.
        emit Finalized();

        // Change the state.
        isFinalized = true;
    }
    
    /**
     * @dev Validate the mininum contribution requirement.
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount)
        internal
        onlyNotFinailized
    {
        super._preValidatePurchase(_beneficiary, _weiAmount);
        require(_weiAmount >= mininumContributeWei);
    }
    

    /**
     * @dev Overrides Crowdsale fund forwarding, sending funds to vault.
     */
    function _forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }
    
    /**
     * @dev Override to add bonus and calculate the sold token amount.
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256)
    {
        uint256 tokens = super._getTokenAmount(_weiAmount);
        
        soldToken = soldToken.add(tokens);
        require(soldToken <= hardCapInToken);
        
        return _addBonus(tokens);
    }
    
    /**
     * @dev Calculate the token amount and add bonus if needed.
     */
    function _addBonus(uint256 _tokenAmount) internal view returns (uint256) {
        
        if (_tokenAmount >= tokenFor10000Usd) {
            _tokenAmount = _tokenAmount.mul(2); // 100% bonus
        } else if (_tokenAmount >= tokenFor5000Usd) {
            _tokenAmount = _tokenAmount.mul(3).div(2); // 50% bonus;
        } else if (_tokenAmount >= tokenFor1000Usd) {
            _tokenAmount = _tokenAmount.mul(5).div(4); // 25% bonus;
        }
        
        require(_tokenAmount <= token.balanceOf(address(this)));
        
        return _tokenAmount;
    }
}
pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol";
import "./openzeppelin-solidity/contracts/crowdsale/distribution/utils/RefundVault.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol";
import "./openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";

/**
 * @title MBACrowdsale
 * @dev Crowdsale with soft cap, hard cap, and two bonus time window. Investors 
 * can get a refund if the soft cap in not met. 
 * Uses a RefundVault as the crowdsale's vault.
 * We use a fixed exchange rate from USD to Token, so the exchange rate between
 * ETH and Token is floating. 
 */
contract MBACrowdsale is FinalizableCrowdsale {
    using SafeMath for uint256;
    
    // Soft cap and hard cap in distributed token.
    uint256 public softCapInToken;
    uint256 public hardCapInToken;
    uint256 public soldToken = 0;
    
    // Mininum contribute: 100 USD.
    uint256 public mininumContributeUSD = 100;
    
    // The floating exchange rate from external API.
    uint256 public decimalsETHToUSD;
    uint256 public exchangeRateETHToUSD;
   
   // The mininum purchase token quantity.
    uint256 public mininumPurchaseTokenQuantity;
    
    // The calculated mininum contribute Wei.
    uint256 public mininumContributeWei;
    
    // The exchange rate from USD to Token.
    // 1 USD => 100 Token (0.005 USD => 1 Token).
    uint256 public exchangeRateUSDToToken = 200;
    
    // The bonus token thresold.
    uint256 public tokenFor1000Usd = exchangeRateUSDToToken * 1000;
    uint256 public tokenFor5000Usd = exchangeRateUSDToToken * 5000;
    uint256 public tokenFor10000Usd = exchangeRateUSDToToken * 10000;
    
    // Refund vault used to hold funds while crowdsale is running
    RefundVault public vault;
    
    // Event 
    event RateUpdated(uint256 rate, uint256 mininumContributeWei);
    
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
        
        // Create the refund vault.
        vault = new RefundVault(_fund);
        
        // Calculate mininum purchase token.
        mininumPurchaseTokenQuantity = exchangeRateUSDToToken * mininumContributeUSD 
           * (10 ** (uint256(erc20Token.decimals())));
        
        // Set default exchange rate ETH => USD: 280.00
        setExchangeRateETHToUSD(28000, 2);
    }
    
    /**
     * @dev Set the exchange rate from ETH to USD.
     * @param _rate The exchange rate.
     * @param _decimals The decimals of input rate.
     */
    function setExchangeRateETHToUSD(uint256 _rate, uint256 _decimals) onlyOwner public {
        // wei * 1e-18 * _rate * 1e(-_decimals) * 1e2          = amount * 1e(-token.decimals);
        // -----------   ----------------------   -------------
        // Wei => ETH      ETH => USD             USD => Token
        //
        // If _rate = 1, wei = 1,
        // Then  amount = 1e(token.decimals + 2 - 18 - _decimals).
        // We need amount >= 1 to ensure the precision.
        
        DetailedERC20 erc20Token = DetailedERC20(token);
        
        require(uint256(erc20Token.decimals()).add(2) >= _decimals.add(18));
        
        exchangeRateETHToUSD = _rate;
        decimalsETHToUSD = _decimals;
        rate = _rate.mul(exchangeRateUSDToToken);
        if (uint256(erc20Token.decimals()) >= _decimals.add(18)) {
            rate = rate.mul(10 ** (uint256(erc20Token.decimals()).sub(18).sub(_decimals)));
        } else {
            rate = rate.div(10 ** (_decimals.add(18).sub(uint256(erc20Token.decimals()))));
        }
        
        mininumContributeWei = mininumPurchaseTokenQuantity.div(rate); 
        
        // Avoid rounding error.
        if (mininumContributeWei * rate < mininumPurchaseTokenQuantity)
            mininumContributeWei += 1;
            
        emit RateUpdated(rate, mininumContributeWei);
    }
    
    /**
     * @dev Investors can claim refunds here if crowdsale is unsuccessful
     */
    function claimRefund() public {
        require(isFinalized);
        require(!softCapReached());

        vault.refund(msg.sender);
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
    function sendTokenToBuyer(address _buyerWallet, uint256 _amount) onlyOwner public {
        require(address(0) != _buyerWallet);
        token.transfer(_buyerWallet, _amount);
        emit TokenPurchase(_buyerWallet, _buyerWallet, 0, _amount);
    }
    
    /**
     * @dev Validate the mininum contribution requirement.
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount)
        internal
    {
        super._preValidatePurchase(_beneficiary, _weiAmount);
        require(_weiAmount >= mininumContributeWei);
    }
    
    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param _beneficiary Address receiving the tokens
     * @param _tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        soldToken = soldToken.add(_tokenAmount);
        require(soldToken <= hardCapInToken);
        
       _tokenAmount = _addBonus(_tokenAmount);
        
        super._processPurchase(_beneficiary, _tokenAmount);
    }
    
    /**
     * @dev Finalization task, called when owner calls finalize()
     */
    function finalization() internal {
        if (softCapReached()) {
            vault.close();
        } else {
            vault.enableRefunds();
        }
        
        // Burn half of the unsold token.
        BurnableToken burnableToken = BurnableToken(token);
        burnableToken.burn(token.balanceOf(address(this)).div(2));
        
        // Transfer the rest token to owner.
        token.transfer(owner, token.balanceOf(address(this)));
        
        super.finalization();
    }

    /**
     * @dev Overrides Crowdsale fund forwarding, sending funds to vault.
     */
    function _forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }
    
    /**
     * @dev Calculate the token amount and add bonus if needed.
     */
    function _addBonus(uint256 _tokenAmount) internal view returns (uint256) {
        DetailedERC20 erc20Token = DetailedERC20(token);
        uint256 tokenInteger = _tokenAmount.div(10 ** uint256(erc20Token.decimals()));
        uint256 usd = tokenInteger.div(exchangeRateUSDToToken);
        
        if (usd >= tokenFor10000Usd) {
            _tokenAmount = _tokenAmount.mul(2); // 100% bonus
        } else if (usd >= tokenFor5000Usd) {
            _tokenAmount = _tokenAmount.mul(3).div(2); // 50% bonus;
        } else if (usd >= tokenFor1000Usd) {
            _tokenAmount = _tokenAmount.mul(5).div(4); // 25% bonus;
        }
        
        require(_tokenAmount <= token.balanceOf(address(this)));
        
        return _tokenAmount;
    }
}
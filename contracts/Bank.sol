//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";


contract Bank is IBank {
    using SafeMath for uint256;
    address constant ethToken = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
    Account ethAccount;
    Account hakAccount;

    
    mapping(address => Account) private ethDepAccountOf;
    mapping(address => Account) private ethBorAccountOf;
    mapping(address => Account) private hakDepAccountOf;
    mapping(address => Account) private hakBorAccountOf;

    
    constructor(address _priceOracle, address _hakToken) {}

    
    /**
     * The purpose of this function is to allow end-users to deposit a given 
     * token amount into their bank account.
     * @param token - the address of the token to deposit. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to deposit is ETH.
     * @param amount - the amount of the given token to deposit.
     * @return - true if the deposit was successful, otherwise revert.
     */
    function deposit(address token, uint256 amount) payable external override returns (bool){
        require(msg.value == amount);
        if (token == this.ethToken){
           ethDepAccountOf[msg.sender].deposit += amount;
           emit Deposit(msg.sender, token, amount);
           return true;
        }   
        else {
            //TODO: find a HAK token identifier
            hakDepAccountOf[msg.sender].deposit += amount;
            emit Deposit(msg.sender, token, amount);
            return true;
        }
    }   
    
      /**
     * The purpose of this function is to allow end-users to withdraw a given 
     * token amount from their bank account. Upon withdrawal, the user must
     * automatically receive a 3% interest rate per 100 blocks on their deposit.
     * @param token - the address of the token to withdraw. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to withdraw is ETH.
     * @param amount - the amount of the given token to withdraw. If this param
     *                 is set to 0, then the maximum amount available in the 
     *                 caller's account should be withdrawn.
     * @return - the amount that was withdrawn plus interest upon success, 
     *           otherwise revert.
     */
    function withdraw(address token, uint256 amount) external override returns (uint256){
        require(msg.value == amount);
        if (token == this.ethToken){
            require(amount <= ethDepAccountOf[msg.sender].deposit);
            emit Withdraw(msg.sender, token, amount);
            ethDepAccountOf[msg.sender].deposit -= amount;
            return ;
        }   
        else {
            //TODO: find a HAK token identifier
            require(amount <= hakDepAccountOf[msg.sender].deposit);
            emit Withdraw(msg.sender, token, amount);
            hakDepAccountOf[msg.sender].deposit -= amount;
            return ;
        }
    }
    
        /**
     * The purpose of this function is to allow users to borrow funds by using their 
     * deposited funds as collateral. The minimum ratio of deposited funds over 
     * borrowed funds must not be less than 150%.
     * @param token - the address of the token to borrow. This address must be
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, otherwise  
     *                the transaction must revert.
     * @param amount - the amount to borrow. If this amount is set to zero (0),
     *                 then the amount borrowed should be the maximum allowed, 
     *                 while respecting the collateral ratio of 150%.
     * @return - the current collateral ratio.
     */
    function borrow(address token, uint256 amount) external override returns (uint256){
    
    }
    
    /**
     * The purpose of this function is to allow users to repay their loans.
     * Loans can be repaid partially or entirely. When replaying a loan, an
     * interest payment is also required. The interest on a loan is equal to
     * 5% of the amount lent per 100 blocks. If the loan is repaid earlier,
     * or later then the interest should be proportional to the number of 
     * blocks that the amount was borrowed for.
     * @param token - the address of the token to repay. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token is ETH.
     * @param amount - the amount to repay including the interest.
     * @return - the amount still left to pay for this loan, excluding interest.
     */
    function repay(address token, uint256 amount) payable external override returns (uint256){
    
    }
    
    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external override returns (bool){
    
    }
    
    /**
     * The purpose of this function is to return the collateral ratio for any account.
     * The collateral ratio is computed as the value deposited divided by the value
     * borrowed. However, if no value is borrowed then the function should return 
     * uint256 MAX_INT = type(uint256).max
     * @param token - the address of the deposited token used a collateral for the loan. 
     * @param account - the account that took out the loan.
     * @return - the value of the collateral ratio with 2 percentage decimals, e.g. 1% = 100.
     *           If the account has no deposits for the given token then return zero (0).
     *           If the account has deposited token, but has not borrowed anything then 
     *           return MAX_INT.
     */
    function getCollateralRatio(address token, address account) view external override returns (uint256){
        if (token == this.ethToken){
            if (ethDepAccountOf[msg.sender].deposit > 0){
                if (ethBorAccountOf[msg.sender].deposit > 0) {
                    return (ethDepAccountOf[msg.sender].deposit /ethBorAccountOf[msg.sender].deposit)*100;
                } else {
                    return type(uint256).max;
                }
            }
            else{
                return 0;
            }
        }
        //TODO: HAK identifier
        else{
            if (hakDepAccountOf[msg.sender].deposit > 0){
                if (hakBorAccountOf[msg.sender].deposit > 0) {
                    return (hakhDepAccountOf[msg.sender].deposit /hakBorAccountOf[msg.sender].deposit)*100;
                } else {
                    return type(uint256).max;
                }
            }
            else{
                return 0;
            }
        }
    }
    
    /**
     * The purpose of this function is to return the balance that the caller 
     * has in their own account for the given token (including interest).
     * @param token - the address of the token for which the balance is computed.
     * @return - the value of the caller's balance with interest, excluding debts.
     */
    function getBalance(address token) view external override returns (uint256){
        if (token == this.ethToken){
           return ethAccountOf[msg.sender].balance + ethAccountOf[msg.sender].interest;
        }   
        else {
            //TODO: find a HAK token identifier
            return hakAccountOf[msg.sender].balance + hakAccountOf[msg.sender].interest;
        }

    }
}
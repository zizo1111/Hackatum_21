//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";
import "./libraries/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";



contract Bank is IBank {

    using DSMath for uint256;
    address private constant ethToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private hakToken; // = 0xBefeeD4CB8c6DD190793b1c97B72B60272f3EA6C;

    mapping(address => Account) private ethDepAccountOf;
    mapping(address => Account) private ethBorAccountOf;
    mapping(address => Account) private hakDepAccountOf;
    // mapping(address => Account) private hakBorAccountOf;
    mapping(address => bool) private ethDepMutexOf;
    mapping(address => bool) private ethBorMutexOf;
    mapping(address => bool) private hakDepMutexOf;
    // mapping(address => bool) private hakBorMutexOf;

    IPriceOracle private priceOracle;

    constructor(address _priceOracle, address _hakToken) {

        priceOracle = IPriceOracle(_priceOracle);
        hakToken = _hakToken;

        console.log('constructor()');
        console.log('constructor()', '_priceOracle:', _priceOracle);
        console.log('constructor()', '_hakToken   :', _hakToken);
        console.log('');

    }


    /**
     * The purpose of this function is to allow end-users to deposit a given 
     * token amount into their bank account.
     * @param token - the address of the token to deposit. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to deposit is ETH.
     * @param amount - the amount of the given token to deposit.
     * @return - true if the deposit was successful, otherwise revert.
     */
    function deposit(address token, uint256 amount) payable external override returns (bool) {

        console.log('deposit()');
        console.log('deposit()', '_hakToken :', hakToken);
        console.log('deposit()', 'token     :', token);
        console.log('deposit()', 'msg.sender:', msg.sender);
        console.log('deposit()', 'amount    :', amount);
        console.log('deposit()', 'msg.value :', msg.value);

        if (token == ethToken) {

            console.log('deposit()', 'Case: ETH');

            require(msg.value == amount);

            require(!ethDepMutexOf[msg.sender]);
            ethDepMutexOf[msg.sender] = true;
            
            require(updateDepInterest(ethDepAccountOf[msg.sender]));

            ethDepAccountOf[msg.sender].deposit = ethDepAccountOf[msg.sender].deposit.add(amount);

            emit Deposit(msg.sender, token, amount);
            
            ethDepMutexOf[msg.sender] = false;

            console.log('');

            return true;

        } else if (token == hakToken) {

            console.log('deposit()', 'Case: HAK');

            require(!hakDepMutexOf[msg.sender]);
            hakDepMutexOf[msg.sender] = true;

            require(updateDepInterest(hakDepAccountOf[msg.sender]));
            
            hakDepAccountOf[msg.sender].deposit = hakDepAccountOf[msg.sender].deposit.add(amount);

            emit Deposit(msg.sender, token, amount);

            hakDepMutexOf[msg.sender] = false;

            console.log('');

            return true;

        } else {

            console.log('deposit()', 'Case: Not supported');
            console.log('');

            revert('token not supported');

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
    function withdraw(address token, uint256 amount) external override returns (uint256) {

        // require(msg.value == amount);

        if (token == ethToken) {
            
            require(!ethDepMutexOf[msg.sender]);
            ethDepMutexOf[msg.sender] = true;
            
            require(updateDepInterest(ethDepAccountOf[msg.sender]));
            
            require(amount <= ethDepAccountOf[msg.sender].deposit + ethDepAccountOf[msg.sender].interest);
            
            if (amount == 0)
            {
                amount = ethDepAccountOf[msg.sender].deposit + ethDepAccountOf[msg.sender].interest;
            }
            
            emit Withdraw(msg.sender, token, amount);
            
            if (amount <= ethDepAccountOf[msg.sender].interest)
            {
                ethDepAccountOf[msg.sender].interest -= amount;
            }
            else
            {
                uint256 currInterest = ethDepAccountOf[msg.sender].interest;
                ethDepAccountOf[msg.sender].interest = 0;
                ethDepAccountOf[msg.sender].deposit -= (amount - currInterest);
            }
            
            ethDepMutexOf[msg.sender] = false;
            return amount;
        }   
        else if(token == hakToken){
            
            //TODO: find a HAK token identifier
            require(!hakDepMutexOf[msg.sender]);
            hakDepMutexOf[msg.sender] = true;
            
            require(updateDepInterest(hakDepAccountOf[msg.sender]));
            
            require(amount <= hakDepAccountOf[msg.sender].deposit + hakDepAccountOf[msg.sender].interest);
            if (amount == 0)
            {
                amount = hakDepAccountOf[msg.sender].deposit + hakDepAccountOf[msg.sender].interest;
            }
            
            emit Withdraw(msg.sender, token, amount);
            
            if (amount <= hakDepAccountOf[msg.sender].interest)
            {
                hakDepAccountOf[msg.sender].interest -= amount;
            }
            else
            {
                uint256 currInterest = hakDepAccountOf[msg.sender].interest;
                hakDepAccountOf[msg.sender].interest = 0;
                hakDepAccountOf[msg.sender].deposit -= (amount - currInterest);
            }
            
            hakDepMutexOf[msg.sender] = false;
            return amount;
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
    function borrow(address token, uint256 amount) external override returns (uint256) {

        //require(msg.value == amount);

        require(token == ethToken);
        
        require((!ethBorMutexOf[msg.sender]) && (!hakDepMutexOf[msg.sender]));
        ethBorMutexOf[msg.sender] = true;
        hakDepMutexOf[msg.sender] = true;
        
        uint256 HAKinETH = priceOracle.getVirtualPrice(hakToken); //address of HAK
        
        uint256 hakDepinETH = hakDepAccountOf[msg.sender].deposit * HAKinETH ;
        uint256 hakInterestinETH = hakDepAccountOf[msg.sender].interest * HAKinETH; 
        
        uint256 collateral_ratio = (hakDepinETH + hakInterestinETH) * 10000 / (ethBorAccountOf[msg.sender].deposit + amount + ethBorAccountOf[msg.sender].interest);
        if (collateral_ratio >= 15000){
            if (amount > 0){
                uint256 newCollateralRatio = collateral_ratio;
                emit Borrow(msg.sender, token, amount, newCollateralRatio);
                ethBorAccountOf[msg.sender].deposit += amount;
                msg.sender.transfer(amount);
            } else if (amount == 0) {
                uint256 amount_max =  (((hakDepAccountOf[msg.sender].deposit + hakDepAccountOf[msg.sender].interest) * 10000 / 15000) - ethBorAccountOf[msg.sender].deposit - ethBorAccountOf[msg.sender].interest); 
                ethBorAccountOf[msg.sender].deposit += amount_max;
                msg.sender.transfer(amount_max);
            }
        }
        
        ethBorMutexOf[msg.sender] = false;
        hakDepMutexOf[msg.sender] = false;
        
        
        return collateral_ratio;
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
    function repay(address token, uint256 amount) payable external override returns (uint256) {

        require(msg.value == amount);
        require(token == ethToken);

        if (token == ethToken) {

            require(!ethBorMutexOf[msg.sender]);
            ethBorMutexOf[msg.sender] = true;

            require(updateBorInterest(ethBorAccountOf[msg.sender]));
            require(amount <= ethBorAccountOf[msg.sender].deposit + ethBorAccountOf[msg.sender].interest);

            emit Repay(msg.sender, token, amount);

            if (amount <= ethBorAccountOf[msg.sender].interest) {
                ethBorAccountOf[msg.sender].interest -= amount;
            } else {
                ethBorAccountOf[msg.sender].interest = 0;
                ethBorAccountOf[msg.sender].deposit -= (amount - ethBorAccountOf[msg.sender].interest);
            }

            ethBorMutexOf[msg.sender] = false;

            return ethBorAccountOf[msg.sender].deposit;
        }

        else {

            // require(!hakBorMutexOf[msg.sender]);
            // hakBorMutexOf[msg.sender] = true;

            // require(updateBorInterest(hakBorAccountOf[msg.sender]));
            // require(amount <= hakBorAccountOf[msg.sender].deposit + hakBorAccountOf[msg.sender].interest);

            // emit Repay(msg.sender, token, amount);

            // if (amount <= hakBorAccountOf[msg.sender].interest) {
            //     hakBorAccountOf[msg.sender].interest -= amount;
            // } else {
            //     hakBorAccountOf[msg.sender].interest = 0;
            //     hakBorAccountOf[msg.sender].deposit -= (amount - hakBorAccountOf[msg.sender].interest);
            // }

            // hakBorMutexOf[msg.sender] = false;

            // return hakBorAccountOf[msg.sender].deposit;
        }

    }


    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external override returns (bool) {

        if (account == msg.sender) {
            revert('cannot liquidate own position');
        }
        require(!ethBorMutexOf[account]);
        ethBorMutexOf[account] = true;

        uint256 HAKinETH = priceOracle.getVirtualPrice(hakToken); //address of HAK
        
        uint256 hakDepinETH = hakDepAccountOf[account].deposit * HAKinETH ;
        uint256 hakInterestinETH = hakDepAccountOf[account].interest * HAKinETH;
        uint256 collateral_ratio = (hakDepinETH + hakInterestinETH) * 10000 / (ethBorAccountOf[account].deposit + ethBorAccountOf[msg.sender].interest);

        require (collateral_ratio < 150);

        if (token == ethToken) {
            //Do what? Should the ethToken be accepted as a collatoral?
            ethBorMutexOf[account] = false;
            return false;
        }

        else {
            require (msg.value >= ethBorAccountOf[account].deposit+ethBorAccountOf[account].interest); //Do we only allow exact replayment? What do we do with the reminder?
            ethDepAccountOf[msg.sender].deposit += ethBorAccountOf[account].deposit;
            ethBorAccountOf[account].deposit = 0;
            ethBorAccountOf[account].interest = 0;
            ethBorMutexOf[account] = false;
            return true;
        }
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
        if (token == hakToken){
            if (hakDepAccountOf[account].deposit > 0){
                if (ethBorAccountOf[account].deposit > 0) {
                    uint256 HAKinETH = priceOracle.getVirtualPrice(hakToken); //address of HAK
        
                    uint256 hakDepinETH = hakDepAccountOf[account].deposit * HAKinETH ;
                    uint256 hakInterestinETH = hakDepAccountOf[account].interest * HAKinETH; 
                    
                    return (hakDepinETH + hakInterestinETH) * 10000 / (ethBorAccountOf[account].deposit + ethBorAccountOf[account].interest);
                }
                else
                {
                    return type(uint256).max;
                }
            }
            else
            {
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
        if (token == ethToken){
  
            return ethDepAccountOf[msg.sender].deposit + checkDepInterest(ethDepAccountOf[msg.sender]);
        }   
        else {
            if (token == ethToken){
                return hakDepAccountOf[msg.sender].deposit + checkDepInterest(hakDepAccountOf[msg.sender]);
            }
            
        }

    }


    /**
     * Update account interest to current block, for deposit/withdraw.
     * @param account_ - user Account. Can be either eth or hak.
     * @return - true if success.
     */
    function updateDepInterest(Account storage account_) private returns (bool) {
        require(block.number - account_.lastInterestBlock > 0);
        account_.interest += account_.deposit * 3 / 100 * (block.number - account_.lastInterestBlock) / 100;
        account_.lastInterestBlock = block.number;
        return true;
    }


    /**
     * Update account interest to current block, for borrow/repay.
     * @param account_ - user Account. Can be either eth or hak.
     * @return - true if success.
     */
    function updateBorInterest(Account storage account_) private returns (bool) {
        require(block.number - account_.lastInterestBlock >= 0);
        account_.interest += account_.deposit * 5 / 100 * (block.number - account_.lastInterestBlock) / 100;
        account_.lastInterestBlock = block.number;
        return true;
    }


    /**
     * Compute account interest without update, for checking account balance.
     * @param account_ - user Account. Can be either eth or hak.
     * @return - current accrued interest.
     */
    function checkDepInterest(Account storage account_) view private returns (uint256) {
        require(block.number - account_.lastInterestBlock >= 0);
        uint256 interest = account_.interest + account_.deposit * 3 / 100 * (block.number - account_.lastInterestBlock) / 100;
        return interest;
    }

}

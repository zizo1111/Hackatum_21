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

        require(amount >= 0);

        if (token == ethToken) {

            console.log('deposit()', 'Case: ETH');

            require(msg.value == amount);

            require(!ethDepMutexOf[msg.sender]);
            ethDepMutexOf[msg.sender] = true;
            
            require(updateDepInterest(ethDepAccountOf[msg.sender]));

            // TODO: How to RECEIVE ETH? .transfer doesn't work?

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

            if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) {
                console.log('deposit()', 'Transaction failed!');
                revert('transaction failed');
            }

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

        console.log('withdraw()');
        console.log('withdraw()', '_hakToken :', hakToken);
        console.log('withdraw()', 'token     :', token);
        console.log('withdraw()', 'msg.sender:', msg.sender);
        console.log('withdraw()', 'amount    :', amount);

        require(amount >= 0);

        if (token == ethToken) {

            console.log('withdraw()', 'Case: ETH');

            // require(msg.value == amount);
            // TypeError: "msg.value" and "callvalue()" can only be used in payable public functions.
            // Make the function "payable" or use an internal function to avoid this error.

            require(!ethDepMutexOf[msg.sender]);
            ethDepMutexOf[msg.sender] = true;

            require(updateDepInterest(ethDepAccountOf[msg.sender]));

            if (ethDepAccountOf[msg.sender].deposit.add(ethDepAccountOf[msg.sender].interest) == 0) {
                revert('no balance');
            }

            if (amount > ethDepAccountOf[msg.sender].deposit.add(ethDepAccountOf[msg.sender].interest)) {
                revert('amount exceeds balance');
            }

            // Withdraw all:
            if (amount == 0) {
                amount = ethDepAccountOf[msg.sender].deposit.add(ethDepAccountOf[msg.sender].interest);
            }

            if (amount <= ethDepAccountOf[msg.sender].interest) {
                ethDepAccountOf[msg.sender].interest = ethDepAccountOf[msg.sender].interest.sub(amount);
            } else {
                ethDepAccountOf[msg.sender].deposit = ethDepAccountOf[msg.sender].deposit.sub(amount - ethDepAccountOf[msg.sender].interest);
                ethDepAccountOf[msg.sender].interest = 0;
            }

            msg.sender.transfer(amount); // .transfer() of ETH.

            emit Withdraw(msg.sender, token, amount);

            ethDepMutexOf[msg.sender] = false;

            console.log('');

            return amount;

        } else if (token == hakToken) {

            console.log('withdraw()', 'Case: HAK');

            require(!hakDepMutexOf[msg.sender]);
            hakDepMutexOf[msg.sender] = true;

            require(updateDepInterest(hakDepAccountOf[msg.sender]));

            if (hakDepAccountOf[msg.sender].deposit.add(hakDepAccountOf[msg.sender].interest) == 0) {
                revert('no balance');
            }

            if (amount > hakDepAccountOf[msg.sender].deposit.add(hakDepAccountOf[msg.sender].interest)) {
                revert('amount exceeds balance');
            }

            // Withdraw all:
            if (amount == 0) {
                amount = hakDepAccountOf[msg.sender].deposit.add(hakDepAccountOf[msg.sender].interest);
            }

            if (amount <= hakDepAccountOf[msg.sender].interest) {
                hakDepAccountOf[msg.sender].interest = hakDepAccountOf[msg.sender].interest.sub(amount);
            } else {
                hakDepAccountOf[msg.sender].deposit = hakDepAccountOf[msg.sender].deposit.sub(amount - hakDepAccountOf[msg.sender].interest);
                hakDepAccountOf[msg.sender].interest = 0;
            }

            IERC20(token).transferFrom(address(this), msg.sender, amount); // .transfer() of ERC20.

            emit Withdraw(msg.sender, token, amount);

            hakDepMutexOf[msg.sender] = false;

            console.log('');

            return amount;

        } else {

            console.log('withdraw()', 'Case: Not supported');
            console.log('');

            revert('token not supported');

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

        console.log('borrow()');
        console.log('borrow()', '_hakToken :', hakToken);
        console.log('borrow()', 'token     :', token);
        console.log('borrow()', 'msg.sender:', msg.sender);
        console.log('borrow()', 'amount    :', amount);

        if (token != ethToken) {
            revert('token not supported');
        }

        require(amount >= 0);

        require((!ethBorMutexOf[msg.sender]) && (!hakDepMutexOf[msg.sender]));
        ethBorMutexOf[msg.sender] = true;
        hakDepMutexOf[msg.sender] = true;

        if (hakDepAccountOf[msg.sender].deposit == 0) {
            revert('no collateral deposited');
        }

        require(updateDepInterest(hakDepAccountOf[msg.sender]));
        require(updateBorInterest(ethBorAccountOf[msg.sender]));

        uint256 HAKinETH = priceOracle.getVirtualPrice(hakToken); //address of HAK
        console.log('borrow()', 'HAKinETH  :', HAKinETH);
        
        uint256 ethBalance      = ethBorAccountOf[msg.sender].deposit.add(ethBorAccountOf[msg.sender].interest);
        uint256 hakBalance      = hakDepAccountOf[msg.sender].deposit.add(hakDepAccountOf[msg.sender].interest);
        uint256 hakBalanceinETH = hakBalance.mul(HAKinETH) / (1 ether);
        console.log('borrow()', 'ethBalance:', ethBalance);
        console.log('borrow()', 'hakBalance:', hakBalance);
        console.log('borrow()', 'hakBalETH :', hakBalanceinETH);

        // Collateral ratio = (Deposited funds in HAK) / (Borrowed funds in ETH):
        uint256 cur_ratio;
        uint256 new_ratio;
        uint256 end_ratio;
        if (ethBalance == 0) {
            cur_ratio = type(uint256).max;
            if (amount > 0) {
                new_ratio = hakBalanceinETH.mul(10000) / ethBalance.add(amount);
            } else if (amount == 0) { // Maximum borrow.
                new_ratio = uint256(15000); // Irrelevant.
            }
        } else {
            cur_ratio = hakBalanceinETH.mul(10000) / ethBalance;
            new_ratio = hakBalanceinETH.mul(10000) / ethBalance.add(amount);
        }
        console.log('borrow()', 'cur_ratio :', cur_ratio);
        console.log('borrow()', 'new_ratio :', new_ratio);

        if (new_ratio >= uint256(15000)) {

            if (amount == 0) {

                console.log('borrow()', 'Case: Max loan.');
                end_ratio = uint256(15000);
                uint256 amount_max = (hakBalanceinETH.mul(10000) / end_ratio).sub(ethBalance);
                console.log('borrow()', 'amount_max:', amount_max);
                ethBorAccountOf[msg.sender].deposit = ethBorAccountOf[msg.sender].deposit.add(amount_max);
                msg.sender.transfer(amount_max); // .transfer() of ETH.
                emit Borrow(msg.sender, token, amount_max, end_ratio);

            } else if (amount > 0) {

                console.log('borrow()', 'Case: Loan approved.');
                end_ratio = new_ratio;
                ethBorAccountOf[msg.sender].deposit = ethBorAccountOf[msg.sender].deposit.add(amount);
                msg.sender.transfer(amount); // .transfer() of ETH.
                emit Borrow(msg.sender, token, amount, end_ratio);

            }

            ethBorMutexOf[msg.sender] = false;
            hakDepMutexOf[msg.sender] = false;

            console.log('borrow()', 'end_ratio :', end_ratio);
            console.log('');

        } else {

            console.log('borrow()', 'Case: Loan rejected.');

            end_ratio = cur_ratio;

            ethBorMutexOf[msg.sender] = false;
            hakDepMutexOf[msg.sender] = false;

            console.log('borrow()', 'end_ratio :', end_ratio);
            console.log('');

            revert('borrow would exceed collateral ratio');

        }

        return end_ratio;

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

        console.log('repay()');
        console.log('repay()', '_hakToken :', hakToken);
        console.log('repay()', 'token     :', token);
        console.log('repay()', 'msg.sender:', msg.sender);
        console.log('repay()', 'amount    :', amount);

        if (token != ethToken) {
            revert('token not supported');
        }

        require(amount >= 0);

        require(!ethBorMutexOf[msg.sender]);
        ethBorMutexOf[msg.sender] = true;

        require(updateBorInterest(ethBorAccountOf[msg.sender]));
        console.log('repay()', 'deposit   :', ethBorAccountOf[msg.sender].deposit);
        console.log('repay()', 'interest  :', ethBorAccountOf[msg.sender].interest);

        if (ethBorAccountOf[msg.sender].deposit.add(ethBorAccountOf[msg.sender].interest) == 0) {
            revert('nothing to repay');
        }

        if (msg.value < amount) { // msg.value wouldn't be zero because we are handling ETH.
            revert('msg.value < amount to repay');
        }

        require(amount <= ethBorAccountOf[msg.sender].deposit.add(ethBorAccountOf[msg.sender].interest), '');

        if (amount == 0) {
            amount = ethBorAccountOf[msg.sender].deposit.add(ethBorAccountOf[msg.sender].interest);
        }

        // TODO: How to RECEIVE ETH? .transfer doesn't work?

        if (amount <= ethBorAccountOf[msg.sender].interest) {
            ethBorAccountOf[msg.sender].interest = ethBorAccountOf[msg.sender].interest.sub(amount);
        } else {
            ethBorAccountOf[msg.sender].deposit = ethBorAccountOf[msg.sender].deposit.sub(amount.sub(ethBorAccountOf[msg.sender].interest));
            ethBorAccountOf[msg.sender].interest = 0;
        }
        console.log('repay()', 'deposit   :', ethBorAccountOf[msg.sender].deposit);
        console.log('repay()', 'interest  :', ethBorAccountOf[msg.sender].interest);

        emit Repay(msg.sender, token, ethBorAccountOf[msg.sender].deposit.add(ethBorAccountOf[msg.sender].interest));

        ethBorMutexOf[msg.sender] = false;

        console.log('');

        return ethBorAccountOf[msg.sender].deposit;

    }


    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external override returns (bool) {

        if (token != hakToken) {
            revert('token not supported');
        }

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
    function getCollateralRatio(address token, address account) view external override returns (uint256) {

        console.log('getCollateralRatio()');
        console.log('getCollateralRatio()', '_hakToken :', hakToken);
        console.log('getCollateralRatio()', 'token     :', token);
        console.log('getCollateralRatio()', 'msg.sender:', msg.sender);
        console.log('getCollateralRatio()', 'account   :', account);

        if (hakDepAccountOf[msg.sender].deposit == 0) {
            // revert('no collateral deposited');
            return 0;
        } else if (ethBorAccountOf[msg.sender].deposit.add(checkBorInterest(ethBorAccountOf[msg.sender])) == 0) {
            return type(uint256).max;
        }

        uint256 HAKinETH = priceOracle.getVirtualPrice(hakToken); //address of HAK
        console.log('getCollateralRatio()', 'HAKinETH  :', HAKinETH);

        uint256 ethBalance      = ethBorAccountOf[msg.sender].deposit.add(checkBorInterest(ethBorAccountOf[msg.sender]));
        uint256 hakBalance      = hakDepAccountOf[msg.sender].deposit.add(checkDepInterest(hakDepAccountOf[msg.sender]));
        uint256 hakBalanceinETH = hakBalance.mul(HAKinETH) / (1 ether);
        console.log('getCollateralRatio()', 'ethBalance:', ethBalance);
        console.log('getCollateralRatio()', 'hakBalance:', hakBalance);
        console.log('getCollateralRatio()', 'hakBalETH :', hakBalanceinETH);

        // Collateral ratio = (Deposited funds in HAK) / (Borrowed funds in ETH):
        uint256 cur_ratio = hakBalanceinETH.mul(10000) / ethBalance;

        console.log('getCollateralRatio()', 'cur_ratio :', cur_ratio);
        console.log('');

        return cur_ratio;

    }


    /**
     * The purpose of this function is to return the balance that the caller 
     * has in their own account for the given token (including interest).
     * @param token - the address of the token for which the balance is computed.
     * @return - the value of the caller's balance with interest, excluding debts.
     */
    function getBalance(address token) view external override returns (uint256) {

        if (token == ethToken){
            return ethDepAccountOf[msg.sender].deposit.add(checkDepInterest(ethDepAccountOf[msg.sender]));
        } else if (token == hakToken) {
            return hakDepAccountOf[msg.sender].deposit.add(checkDepInterest(hakDepAccountOf[msg.sender]));
        } else {
            revert('token not supported');
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


    /**
     * Compute borrow interest without update, for checking account balance.
     * @param account_ - user Account. Can be either eth or hak.
     * @return - current accrued interest.
     */
    function checkBorInterest(Account storage account_) view private returns (uint256) {
        require(block.number - account_.lastInterestBlock >= 0);
        uint256 interest = account_.interest + account_.deposit * 5 / 100 * (block.number - account_.lastInterestBlock) / 100;
        return interest;
    }

}

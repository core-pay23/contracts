// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PaymentGatewayDirect
 * @dev Simplified PaymentGatewayDirect for local transaction creation
 * @dev Handles transaction creation and payment processing with payment token specification
 */
contract PaymentGatewayDirect is Ownable {
    using SafeERC20 for IERC20;
    
    // Constants
    uint256 public constant TAX_RATE = 50; // 0.5% represented as 50 basis points
    uint256 public constant BASIS_POINTS = 10000;
    
    // State variables
    address public taxAddress;
    mapping(address => bool) public allowedTokens;
    uint256 private transactionCounter;
    bool private locked; // Reentrancy protection
    
    // Transaction struct
    struct Transaction {
        uint256 id;
        address payer; // Address of the person who will pay
        string originChain;
        uint256 totalPayment; // Total amount user will pay
        address shopOwner; // EOA wallet of the shop owner
        address paymentToken; // Token for payment (0x0 for native token)
        uint256 timestamp;
        bool isPaid;
        bool isRefunded;
        uint256 taxAmount; // Tax amount deducted from totalPayment
        uint256 shopOwnerAmount; // Amount shop owner receives
    }
    
    // Mappings
    mapping(uint256 => Transaction) public transactions;
    mapping(address => uint256[]) public payerTransactions;
    mapping(address => uint256[]) public shopOwnerTransactions;
    
    // Events
    event TransactionCreated(
        uint256 indexed transactionId,
        address indexed shopOwner,
        uint256 totalPayment,
        string originChain,
        address paymentToken
    );
    
    event TransactionPaid(
        uint256 indexed transactionId,
        address indexed payer,
        address indexed shopOwner,
        address paymentToken,
        uint256 paymentAmount,
        uint256 taxAmount
    );
    
    event TransactionRefunded(
        uint256 indexed transactionId,
        address indexed payer,
        uint256 refundAmount
    );
    
    event TaxAddressUpdated(address indexed oldTaxAddress, address indexed newTaxAddress);
    event TokenAllowed(address indexed token);
    event TokenRemoved(address indexed token);
    
    // Modifiers
    modifier nonReentrant() {
        require(!locked, "PaymentGatewayDirect: reentrant call");
        locked = true;
        _;
        locked = false;
    }
    
    modifier validTransaction(uint256 _transactionId) {
        require(_transactionId > 0 && _transactionId <= transactionCounter, "PaymentGatewayDirect: invalid transaction ID");
        _;
    }
    
    modifier notPaid(uint256 _transactionId) {
        require(!transactions[_transactionId].isPaid, "PaymentGatewayDirect: transaction already paid");
        _;
    }
    
    modifier isPaid(uint256 _transactionId) {
        require(transactions[_transactionId].isPaid, "PaymentGatewayDirect: transaction not paid yet");
        _;
    }
    
    modifier notRefunded(uint256 _transactionId) {
        require(!transactions[_transactionId].isRefunded, "PaymentGatewayDirect: transaction already refunded");
        _;
    }
    
    /**
     * @dev Constructor initializes payment gateway
     * @param _taxAddress Address where tax will be sent
     * @param _allowedTokens Array of initial allowed token addresses
     * @param _owner Owner of the contract
     */
    constructor(
        address _taxAddress,
        address[] memory _allowedTokens,
        address _owner
    ) Ownable(_owner) {
        require(_taxAddress != address(0), "PaymentGatewayDirect: tax address cannot be zero address");
        
        taxAddress = _taxAddress;
        
        // Add all provided tokens to allowed list
        for (uint256 i = 0; i < _allowedTokens.length; i++) {
            require(_allowedTokens[i] != address(0), "PaymentGatewayDirect: token address cannot be zero address");
            allowedTokens[_allowedTokens[i]] = true;
            emit TokenAllowed(_allowedTokens[i]);
        }
        
        emit TaxAddressUpdated(address(0), _taxAddress);
    }
    
    /**
     * @dev Internal function to create a new transaction
     * @param _originChain Chain where the transaction originates
     * @param _totalPayment Total payment amount that user will pay
     * @param _shopOwner EOA wallet address of the shop owner
     * @param _payer Address of the user who will pay
     * @param _paymentToken Token for payment (0x0 for native token)
     * @return transactionId The ID of the created transaction
     */
    function _createTransaction(
        string memory _originChain,
        uint256 _totalPayment,
        address _shopOwner,
        address _payer,
        address _paymentToken
    ) internal returns (uint256) {
        require(_shopOwner != address(0), "PaymentGatewayDirect: shop owner cannot be zero address");
        require(_totalPayment > 0, "PaymentGatewayDirect: payment amount must be greater than zero");
        require(bytes(_originChain).length > 0, "PaymentGatewayDirect: origin chain cannot be empty");
        require(_payer != address(0), "PaymentGatewayDirect: payer cannot be zero address");
        
        transactionCounter++;
        uint256 taxAmount = calculateTax(_totalPayment);
        uint256 shopOwnerAmount = calculateShopOwnerAmount(_totalPayment);
        
        Transaction memory newTransaction = Transaction({
            id: transactionCounter,
            payer: _payer,
            originChain: _originChain,
            totalPayment: _totalPayment,
            shopOwner: _shopOwner,
            paymentToken: _paymentToken,
            timestamp: block.timestamp,
            isPaid: false,
            isRefunded: false,
            taxAmount: taxAmount,
            shopOwnerAmount: shopOwnerAmount
        });
        
        transactions[transactionCounter] = newTransaction;
        shopOwnerTransactions[_shopOwner].push(transactionCounter);
        payerTransactions[_payer].push(transactionCounter);
        
        emit TransactionCreated(
            transactionCounter,
            _shopOwner,
            _totalPayment,
            _originChain,
            _paymentToken
        );
        
        return transactionCounter;
    }
    
    /**
     * @dev Creates a new transaction
     * @param _originChain Chain where the transaction originates
     * @param _totalPayment Total payment amount that user will pay
     * @param _shopOwner EOA wallet address of the shop owner
     * @param _paymentToken Token for payment (0x0 for native token)
     * @return transactionId The ID of the created transaction
     */
    function createTransaction(
        string memory _originChain,
        uint256 _totalPayment,
        address _shopOwner,
        address _paymentToken
    ) external returns (uint256) {
        // Validate payment token if not native token
        if (_paymentToken != address(0)) {
            require(allowedTokens[_paymentToken], "PaymentGatewayDirect: token not allowed");
        }
        
        return _createTransaction(_originChain, _totalPayment, _shopOwner, msg.sender, _paymentToken);
    }
    
    /**
     * @dev Calculates tax amount for a given total payment
     * @param _totalPayment Total payment amount that user will pay
     * @return Tax amount to be deducted
     */
    function calculateTax(uint256 _totalPayment) public pure returns (uint256) {
        return (_totalPayment * TAX_RATE) / BASIS_POINTS;
    }
    
    /**
     * @dev Calculates shop owner amount after tax deduction
     * @param _totalPayment Total payment amount that user will pay
     * @return Amount that shop owner will receive
     */
    function calculateShopOwnerAmount(uint256 _totalPayment) public pure returns (uint256) {
        uint256 taxAmount = calculateTax(_totalPayment);
        return _totalPayment - taxAmount;
    }
    
    /**
     * @dev Processes payment for a transaction
     * @param _transactionId ID of the transaction to pay
     */
    function payTransaction(uint256 _transactionId) 
        external 
        payable 
        validTransaction(_transactionId) 
        notPaid(_transactionId) 
        nonReentrant
    {
        Transaction storage transaction = transactions[_transactionId];
        
        require(transaction.paymentToken == address(0), "PaymentGatewayDirect: payment token mismatch");
        require(msg.value == transaction.totalPayment, "PaymentGatewayDirect: incorrect payment amount");
        
        // Update payer if needed
        address actualPayer = msg.sender;
        
        if (transaction.payer != actualPayer) {
            payerTransactions[actualPayer].push(_transactionId);
            transaction.payer = actualPayer;
        }
        
        // Update state before external calls
        transaction.isPaid = true;
        
        // Send tax to tax address
        (bool successTax, ) = payable(taxAddress).call{value: transaction.taxAmount}("");
        require(successTax, "PaymentGatewayDirect: failed to send tax to tax address");
        
        // Send payment directly to shop owner
        (bool successPayment, ) = payable(transaction.shopOwner).call{value: transaction.shopOwnerAmount}("");
        require(successPayment, "PaymentGatewayDirect: failed to send payment to shop owner");
        
        emit TransactionPaid(_transactionId, transaction.payer, transaction.shopOwner, address(0), transaction.shopOwnerAmount, transaction.taxAmount);
    }
    
    /**
     * @dev Processes payment for a transaction using ERC20 token
     * @dev Open to everyone - no authorization required
     * @param _transactionId ID of the transaction to pay
     * @return True if payment successful
     */
    function payTransactionWithToken(
        uint256 _transactionId
    ) 
        external 
        validTransaction(_transactionId) 
        notPaid(_transactionId) 
        nonReentrant
        returns (bool)
    {
        Transaction storage transaction = transactions[_transactionId];
        
        require(transaction.paymentToken != address(0), "PaymentGatewayDirect: payment token mismatch");
        require(allowedTokens[transaction.paymentToken], "PaymentGatewayDirect: token not allowed");
        
        // Update payer if needed
        address actualPayer = msg.sender;
        
        if (transaction.payer != actualPayer) {
            payerTransactions[actualPayer].push(_transactionId);
            transaction.payer = actualPayer;
        }
        
        // Update state before external calls
        transaction.isPaid = true;
        
        // Transfer tokens from payer to this contract, then distribute
        IERC20(transaction.paymentToken).safeTransferFrom(
            actualPayer, 
            address(this), 
            transaction.totalPayment
        );
        
        // Send tax to tax address
        IERC20(transaction.paymentToken).safeTransfer(taxAddress, transaction.taxAmount);
        
        // Send payment directly to shop owner
        IERC20(transaction.paymentToken).safeTransfer(transaction.shopOwner, transaction.shopOwnerAmount);
        
        emit TransactionPaid(
            _transactionId, 
            transaction.payer, 
            transaction.shopOwner, 
            transaction.paymentToken,
            transaction.shopOwnerAmount, 
            transaction.taxAmount
        );
        
        return true;
    }
    
    /**
     * @dev Refunds a transaction
     * @param _transactionId ID of the transaction to refund
     */
    function refundTransaction(uint256 _transactionId) 
        external 
        payable
        validTransaction(_transactionId) 
        isPaid(_transactionId) 
        notRefunded(_transactionId)
        nonReentrant
    {
        Transaction storage transaction = transactions[_transactionId];
        
        require(msg.sender == transaction.shopOwner, "PaymentGatewayDirect: only shop owner can refund");
        
        if (transaction.paymentToken == address(0)) {
            // Native token refund
            require(msg.value == transaction.shopOwnerAmount, "PaymentGatewayDirect: incorrect refund amount");
            
            transaction.isRefunded = true;
            
            (bool success, ) = payable(transaction.payer).call{value: transaction.shopOwnerAmount}("");
            require(success, "PaymentGatewayDirect: failed to send refund to payer");
        } else {
            // Token refund
            transaction.isRefunded = true;
            
            IERC20(transaction.paymentToken).safeTransferFrom(
                msg.sender,
                transaction.payer,
                transaction.shopOwnerAmount
            );
        }
        
        emit TransactionRefunded(_transactionId, transaction.payer, transaction.shopOwnerAmount);
    }
    
    /**
     * @dev Gets transaction details
     * @param _transactionId ID of the transaction
     * @return Transaction details
     */
    function getTransaction(uint256 _transactionId) 
        external 
        view 
        validTransaction(_transactionId) 
        returns (Transaction memory) 
    {
        return transactions[_transactionId];
    }
    
    /**
     * @dev Gets all transaction IDs for a payer
     * @param _payer Payer address
     * @return Array of transaction IDs
     */
    function getPayerTransactions(address _payer) external view returns (uint256[] memory) {
        return payerTransactions[_payer];
    }
    
    /**
     * @dev Gets all transaction IDs for a shop owner
     * @param _shopOwner Shop owner address
     * @return Array of transaction IDs
     */
    function getShopOwnerTransactions(address _shopOwner) external view returns (uint256[] memory) {
        return shopOwnerTransactions[_shopOwner];
    }
    
    /**
     * @dev Gets the current transaction counter
     * @return Current transaction counter value
     */
    function getTransactionCounter() external view returns (uint256) {
        return transactionCounter;
    }
    
    /**
     * @dev Updates the tax address (only owner)
     * @param _newTaxAddress New tax address
     */
    function updateTaxAddress(address _newTaxAddress) external onlyOwner {
        require(_newTaxAddress != address(0), "PaymentGatewayDirect: new tax address cannot be zero address");
        address oldTaxAddress = taxAddress;
        taxAddress = _newTaxAddress;
        emit TaxAddressUpdated(oldTaxAddress, _newTaxAddress);
    }
    
    /**
     * @dev Adds a token to the allowed tokens list (only owner)
     * @param _token Token address to add
     */
    function addAllowedToken(address _token) external onlyOwner {
        require(_token != address(0), "PaymentGatewayDirect: token address cannot be zero address");
        require(!allowedTokens[_token], "PaymentGatewayDirect: token already allowed");
        
        allowedTokens[_token] = true;
        emit TokenAllowed(_token);
    }
    
    /**
     * @dev Removes a token from the allowed tokens list (only owner)
     * @param _token Token address to remove
     */
    function removeAllowedToken(address _token) external onlyOwner {
        require(_token != address(0), "PaymentGatewayDirect: token address cannot be zero address");
        require(allowedTokens[_token], "PaymentGatewayDirect: token not allowed");
        
        allowedTokens[_token] = false;
        emit TokenRemoved(_token);
    }
    
    /**
     * @dev Checks if a token is allowed for payments
     * @param _token Token address to check
     * @return True if token is allowed
     */
    function isTokenAllowed(address _token) external view returns (bool) {
        return allowedTokens[_token];
    }
    
    /**
     * @dev Emergency function to withdraw any stuck native tokens (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "PaymentGatewayDirect: no funds to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "PaymentGatewayDirect: withdrawal failed");
    }
    
    /**
     * @dev Fallback function to reject direct payments
     */
    receive() external payable {
        revert("PaymentGatewayDirect: direct payments not accepted");
    }
    
    /**
     * @dev Fallback function to reject calls to non-existent functions
     */
    fallback() external payable {
        revert("PaymentGatewayDirect: function does not exist");
    }
}

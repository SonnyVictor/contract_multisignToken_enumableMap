// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ownerLib.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";


contract MultisignToken is  Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdt;

    using OwnerLibrary for OwnerLibrary.OwnerStorage;
    OwnerLibrary.OwnerStorage private _ownerStorage;

    constructor() Ownable(msg.sender){}

    function addOwner(address _owner) external onlyOwner() {
        _ownerStorage.addOwner(_owner);
    }

    function getOwner() external view returns(address[] memory) {
        return _ownerStorage.valueOwner();
    }

    function isOwner(address _owner) external view returns (bool) {
        return _ownerStorage.isOwnerSupported(_owner);
    }

    struct Transaction {
        address to;           
        uint256 value;        
        bool executed;        
        uint256 confirmations;
        uint256 timeEnd; 
    }

    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;
    uint256 public requiredConfirmations;

    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public timeEnd = 1 days;

    event SubmitTransaction(address indexed signer, uint256 indexed txIndex, address indexed to, uint256 value,uint256 timeEnd);
    event ConfirmTransaction(address indexed signer, uint256 indexed txIndex,uint256 time);
    event ExecuteTransaction(address indexed signer, uint256 indexed txIndex,uint256 time);
    event RevokeConfirmation(address indexed signer, uint256 indexed txIndex,uint256 time);

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactionCount, "Transaction does not exist");
        _;
    }
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }
    modifier notConfirmed(uint256 _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed by this signer");
        _;
    }

    modifier notSigner(address _owner){
        require(_ownerStorage.isOwnerSupported(_owner),"You are not owner signer");
        _;
    }

    function submitTransaction(address _to, uint256 _value) public onlyOwner() {
        uint256 txIndex = transactionCount;
        transactions[txIndex] = Transaction({
            to: _to,
            value: _value,
            executed: false,
            confirmations: 0,
            timeEnd: block.timestamp + timeEnd

        });
        transactionCount++;
        emit SubmitTransaction(msg.sender, txIndex, _to, _value,block.timestamp + timeEnd);
    }
    
    function confirmTransaction(uint256 _txIndex) public  txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) notSigner(msg.sender)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations += 1 ;
        confirmations[_txIndex][msg.sender] = true;
        emit ConfirmTransaction(msg.sender, _txIndex,block.timestamp);
    }

    function executeTransaction(uint256 _txIndex)
        public   
        txExists(_txIndex)
        notExecuted(_txIndex)
        notSigner(msg.sender)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations >= requiredConfirmations, "Not enough confirmations");
        transaction.executed = true;
        IERC20(usdt).safeTransferFrom(address(this),transaction.to, transaction.value);
        emit ExecuteTransaction(msg.sender, _txIndex,block.timestamp);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        notSigner(msg.sender)
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed by this signer");
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations > 0, "No confirmations to revoke");
        transaction.confirmations -= 1;
        confirmations[_txIndex][msg.sender] = false;
        emit RevokeConfirmation(msg.sender, _txIndex,block.timestamp);
    }


    function setUSDT(IERC20 _usdtoken) external onlyOwner() {
        usdt = _usdtoken;
    }   

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getTransaction(uint256 _txIndex)
        external
        view
        returns (address to, uint256 value, bool executed, uint256 confirmationsCount, uint256 time)
    {
        Transaction memory transaction = transactions[_txIndex];
        return (transaction.to, transaction.value, transaction.executed, transaction.confirmations,time);
    }
}
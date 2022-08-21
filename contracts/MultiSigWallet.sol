//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MultiSigWallet {
    //Structure to hold transaction information
    struct TransactionInfo {
        address dest;
        uint256 value;
        bytes data;
        bool isExecuted;
        uint8 approvalCount;
        mapping(address => bool) approveOwners;
    }

    event Deposit(address indexed sender, uint256 value);
    event Approve(address indexed approver, uint256 indexed txid);
    event RevokeApproval(address indexed approver, uint256 indexed txid);
    event TxSubmitted(address indexed sender, uint256 indexed txid);
    event TxExecuted(address indexed executor, uint256 indexed txid);

    //Threshold to have minimum no of owners to execute a transaction
    uint public confirmationThreshold;

    //List to hold all the owner's address
    address[] public owners;

    //Mapping to hold addresses to get if its an owner in a non-loop way
    mapping(address => bool) private mapOwners;

    TransactionInfo[] public transactions;

    modifier onlyOwner() {
        require(
            msg.sender != address(0) && mapOwners[msg.sender],
            "Not a valid owner"
        );
        _;
    }

    modifier validTxn(uint256 txid) {
        require(txid < transactions.length, "Not a valid transaction id");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(
            _threshold <= _owners.length && _threshold > 0,
            "owners and threshold should be correct"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert("Not a vlid address");

            if (mapOwners[owner]) revert("Duplicate owners not allowed.");

            mapOwners[owner] = true;
        }
        owners = _owners;
        confirmationThreshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(
        address _dest,
        uint256 _value,
        bytes calldata _data
    ) external returns (uint256 txid) {
        require(_dest != address(0), "Not a valid destination address");

        TransactionInfo storage txn = transactions.push();
        txn.dest = _dest;
        txn.value = _value;
        txn.data = _data;

        txid = transactions.length - 1;
        emit TxSubmitted(msg.sender, txid);
    }

    function approveTransaction(uint _txid) external onlyOwner validTxn(_txid) {
        TransactionInfo storage ti = transactions[_txid];

        if (ti.approveOwners[msg.sender])
            revert("Already approved by the sender");

        ti.approveOwners[msg.sender] = true;
        ti.approvalCount += 1;

        emit Approve(msg.sender, _txid);
    }

    function revokeApproval(uint _txid) external onlyOwner validTxn(_txid) {
        TransactionInfo storage ti = transactions[_txid];

        require(
            ti.approveOwners[msg.sender],
            "sender has not yet approved txn"
        );
        require(!ti.isExecuted, "Transaction is already executed.");

        ti.approvalCount -= 1;
        ti.approveOwners[msg.sender] = false;
        emit RevokeApproval(msg.sender, _txid);
    }

    function executeTransaction(uint256 _txid) external validTxn(_txid) {
        TransactionInfo storage ti = transactions[_txid];

        require(!ti.isExecuted, "Already executed");
        require(
            ti.approvalCount >= confirmationThreshold,
            "Not enough approvals"
        );
        require(address(this).balance >= ti.value, "Not enough balance");

        ti.isExecuted = true;
        emit TxExecuted(msg.sender, _txid);
        (bool success, ) = address(ti.dest).call{value: ti.value}(ti.data);
        require(success, "transaction failed.");
    }
}

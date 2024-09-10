// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Multisig {
    uint8 public quorum;
    uint8 public noOfValidSigners;
    uint256 public txCount;

    struct Transaction {
        uint256 id;
        uint256 amount;
        address sender;
        address recipient;
        bool isCompleted;
        uint256 timestamp;
        uint256 noOfApproval;
        address tokenAddress;
        address[] transactionSigners;
    }

    struct QuorumUpdate {
        uint256 id;
        uint8 newQuorum;
        bool isCompleted;
        uint256 noOfApproval;
        address[] updateSigners;
    }

    mapping(address => bool) isValidSigner;
    mapping(uint => Transaction) transactions; // txId -> Transaction
    mapping(uint => QuorumUpdate) quorumUpdates; // txId -> QuorumUpdate
    mapping(address => mapping(uint256 => bool)) hasSigned;
    mapping(address => mapping(uint256 => bool)) hasSignedQuorum;

    constructor(uint8 _quorum, address[] memory _validSigners) {
        require(_validSigners.length > 1, "few valid signers");
        require(_quorum > 1, "quorum is too small");

        for (uint256 i = 0; i < _validSigners.length; i++) {
            require(_validSigners[i] != address(0), "zero address not allowed");
            require(!isValidSigner[_validSigners[i]], "signer already exists");

            isValidSigner[_validSigners[i]] = true;
        }

        noOfValidSigners = uint8(_validSigners.length);

        if (!isValidSigner[msg.sender]) {
            isValidSigner[msg.sender] = true;
            noOfValidSigners += 1;
        }

        require(_quorum <= noOfValidSigners, "quorum greater than valid signers");
        quorum = _quorum;
    }

    // Transfer function
    function transfer(uint256 _amount, address _recipient, address _tokenAddress) external {
        require(msg.sender != address(0), "address zero found");
        require(isValidSigner[msg.sender], "invalid signer");

        require(_amount > 0, "can't send zero amount");
        require(_recipient != address(0), "address zero found");
        require(_tokenAddress != address(0), "address zero found");

        require(IERC20(_tokenAddress).balanceOf(address(this)) >= _amount, "insufficient funds");

        uint256 _txId = txCount;  // Fix: Correct transaction ID assignment
        Transaction storage trx = transactions[_txId];

        trx.id = _txId;
        trx.amount = _amount;
        trx.recipient = _recipient;
        trx.sender = msg.sender;
        trx.timestamp = block.timestamp;
        trx.tokenAddress = _tokenAddress;
        trx.noOfApproval = 1;  // Fix: Initialize noOfApproval
        trx.transactionSigners.push(msg.sender);
        hasSigned[msg.sender][_txId] = true;

        txCount += 1;  // Fix: Increment txCount after assignment
    }

    // Function to propose a quorum update
    function proposeQuorumUpdate(uint8 _newQuorum) external {
        require(isValidSigner[msg.sender], "invalid signer");
        require(_newQuorum > 1 && _newQuorum <= noOfValidSigners, "invalid quorum");

        uint256 _txId = txCount;
        QuorumUpdate storage update = quorumUpdates[_txId];
        update.id = _txId;
        update.newQuorum = _newQuorum;
        update.noOfApproval = 1; // proposer is counted as the first approval
        update.updateSigners.push(msg.sender);
        hasSignedQuorum[msg.sender][_txId] = true;

        txCount += 1;
    }

    // Function to approve a quorum update
    function approveQuorumUpdate(uint256 _txId) external {
        QuorumUpdate storage update = quorumUpdates[_txId];

        require(update.id != 0, "invalid tx id");
        require(!update.isCompleted, "quorum update already completed");
        require(update.noOfApproval < quorum, "approvals already reached quorum");

        require(isValidSigner[msg.sender], "not a valid signer");
        require(!hasSignedQuorum[msg.sender][_txId], "can't sign twice");

        hasSignedQuorum[msg.sender][_txId] = true;
        update.noOfApproval += 1;
        update.updateSigners.push(msg.sender);

        if (update.noOfApproval == quorum) {
            quorum = update.newQuorum;
            update.isCompleted = true;
        }
    }

    function approveTx(uint8 _txId) external {
        Transaction storage trx = transactions[_txId];

        require(trx.id != 0, "invalid tx id");

        require(IERC20(trx.tokenAddress).balanceOf(address(this)) >= trx.amount, "insufficient funds");
        require(!trx.isCompleted, "transaction already completed");
        require(trx.noOfApproval < quorum, "approvals already reached quorum");  // Fix: Edge case for quorum

        require(isValidSigner[msg.sender], "not a valid signer");
        require(!hasSigned[msg.sender][_txId], "can't sign twice");

        hasSigned[msg.sender][_txId] = true;
        trx.noOfApproval += 1;
        trx.transactionSigners.push(msg.sender);

        if(trx.noOfApproval == quorum) {
            trx.isCompleted = true;
            IERC20(trx.tokenAddress).transfer(trx.recipient, trx.amount);  // Fix: Transfer tokens upon reaching quorum
        }
    }
}

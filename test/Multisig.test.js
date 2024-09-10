const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Multisig", function () {
    let Multisig;
    let multisig;
    let owner, addr1, addr2, addr3, addr4, addr5, addr6;
    let token;
    let quorum = 3;  

    beforeEach(async function () {
        
        Multisig = await ethers.getContractFactory("Multisig");
        Token = await ethers.getContractFactory("MyToken"); 

       
        [owner, addr1, addr2, addr3, addr4, addr5, addr6] = await ethers.getSigners();

        token = await Token.deploy(ethers.utils.parseEther("1000")); 
        await token.deployed();

        multisig = await Multisig.deploy(quorum, [addr1.address, addr2.address, addr3.address]);
        await multisig.deployed();

       
        await token.transfer(multisig.address, ethers.utils.parseEther("500"));
    });

    it("Should initialize with valid signers and quorum", async function () {
        expect(await multisig.quorum()).to.equal(quorum);
        expect(await multisig.noOfValidSigners()).to.equal(3);
    });

    it("Should only allow valid signers to create a transaction", async function () {
        await expect(
            multisig.connect(addr4).transfer(ethers.utils.parseEther("100"), addr5.address, token.address)
        ).to.be.revertedWith("invalid signer");

        
        await multisig.connect(addr1).transfer(ethers.utils.parseEther("100"), addr5.address, token.address);
        const tx = await multisig.transactions(1); // Transaction with ID 1
        expect(tx.amount).to.equal(ethers.utils.parseEther("100"));
    });

    it("Should allow valid signers to approve and execute a transaction after quorum", async function () {
        // Create a transfer
        await multisig.connect(addr1).transfer(ethers.utils.parseEther("100"), addr5.address, token.address);

        // First approval
        await multisig.connect(addr1).approveTx(1);
        const tx1 = await multisig.transactions(1);
        expect(tx1.noOfApproval).to.equal(1);

        // Second approval
        await multisig.connect(addr2).approveTx(1);
        const tx2 = await multisig.transactions(1);
        expect(tx2.noOfApproval).to.equal(2);

        // Third approval - should execute the transaction
        await multisig.connect(addr3).approveTx(1);
        const tx3 = await multisig.transactions(1);
        expect(tx3.isCompleted).to.be.true;

        // Check recipient balance
        const recipientBalance = await token.balanceOf(addr5.address);
        expect(recipientBalance).to.equal(ethers.utils.parseEther("100"));
    });

    it("Should revert if approvals exceed quorum or signer signs twice", async function () {
        await multisig.connect(addr1).transfer(ethers.utils.parseEther("100"), addr5.address, token.address);

        // First approval
        await multisig.connect(addr1).approveTx(1);

        // Attempt to sign the same transaction again
        await expect(multisig.connect(addr1).approveTx(1)).to.be.revertedWith("can't sign twice");

        // Approve the transaction by addr2 and addr3 to reach the quorum
        await multisig.connect(addr2).approveTx(1);
        await multisig.connect(addr3).approveTx(1);

        // Transaction is now completed, attempting another approval should revert
        await expect(multisig.connect(addr4).approveTx(1)).to.be.revertedWith("transaction already completed");
    });

    it("Should allow quorum to be updated by valid signers", async function () {
        // Adding a test for updating the quorum
        await multisig.connect(addr1).proposeQuorumUpdate(4); // Assume you add proposeQuorumUpdate function in the contract

        // Approve the quorum update by the valid signers
        await multisig.connect(addr1).approveQuorumUpdate();
        await multisig.connect(addr2).approveQuorumUpdate();
        await multisig.connect(addr3).approveQuorumUpdate();

        // Check if quorum was updated
        expect(await multisig.quorum()).to.equal(4);
    });
});

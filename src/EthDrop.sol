// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ICredentialRegistry} from "bringid/ICredentialRegistry.sol";
import {Ownable, Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";

error AirdropClaimed(address to);
error AirdropStopped();
error InsufficientScore(uint256 score);
error TransferFailed();
error AmountIsZero();
error ThresholdIsZero();

event Claimed(address to, uint256 amount);
event StatusUpdated(bool isRunning);
event AmountPerClaimUpdated(uint256 amount);
event ScoreThresholdUpdated(uint256 threshold);
event Withdrawn(address to, uint256 amount);

contract EthDrop is Ownable2Step {
    ICredentialRegistry public immutable REGISTRY;

    mapping(address => bool) public isClaimed;
    uint256 public claims;
    bool public running = false;
    uint256 public amount;
    uint256 public scoreThreshold = 10;

    constructor(ICredentialRegistry registry) Ownable() {
        REGISTRY = registry;
    }

    function claim(
        address to,
        ICredentialRegistry.CredentialGroupProof[] calldata proofs
    ) public {
        if(!running) revert AirdropStopped();

        if(isClaimed[to]) revert AirdropClaimed(to);
        isClaimed[to] = true;

        uint256 totalScore = REGISTRY.score(0, proofs);
        if(totalScore < scoreThreshold) revert InsufficientScore(totalScore);

        uint256 available = address(this).balance;
        if (amount >= available) {
            amount = available;
            running = false;
        }

        claims++;

        (bool success, ) = payable(to).call{value: amount}("");
        if(!success) revert TransferFailed();
    }

    // ONLY OWNER //
    function withdraw(
        address to,
        uint256 amountToWithdraw
    ) public onlyOwner {
        running = false;
        (bool success, ) = payable(to).call{value: amountToWithdraw}("");
        if(!success) revert TransferFailed();
        emit Withdrawn(to, amount);
    }

    function setAmount(uint256 newAmount) public onlyOwner {
        if(newAmount == 0) revert AmountIsZero();
        amount = newAmount;
        emit AmountPerClaimUpdated(newAmount);
    }

    function setScoreThreshold(uint256 newThreshold) public onlyOwner {
        if(newThreshold == 0) revert ThresholdIsZero();
        scoreThreshold = newThreshold;
        emit ScoreThresholdUpdated(newThreshold);
    }

    function setStatus(bool isRunning) public onlyOwner {
        running = isRunning;
        emit StatusUpdated(isRunning);
    }
}

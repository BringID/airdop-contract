// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";

error TransferFailed();
error RelayerAddressIsZero();
error AmountIsZero();
error SenderIsNotRelayer();

event Claimed(address to, uint256 amount);
event Withdrawn(address to, uint256 amount);
event StatusUpdated(bool status);
event RelayerUpdated(address relayer);
event AmountPerClaimUpdated(uint256 relayer);

contract EthFaucet is Ownable2Step {
    bool public running;
    address public relayer;
    uint256 public amount;

    modifier onlyRelayer() {
        if (msg.sender != relayer) revert SenderIsNotRelayer();
        _;
    }

    function claim(address to) public onlyRelayer {
        (bool success, ) = payable(to).call{value: amount}("");
        if(!success) revert TransferFailed();
        emit Claimed(to, amount);
    }

    function withdraw(
        address to,
        uint256 amountToWithdraw
    ) public onlyOwner {
        running = false;
        (bool success, ) = payable(to).call{value: amountToWithdraw}("");
        if(!success) revert TransferFailed();
        emit Withdrawn(to, amount);
    }

    function setStatus(bool isRunning) public onlyOwner {
        running = isRunning;
        emit StatusUpdated(isRunning);
    }

    function setRelayer(address newRelayer) public onlyOwner {
        if(newRelayer == address(0)) revert RelayerAddressIsZero();
        relayer = newRelayer;
        emit RelayerUpdated(newRelayer);
    }

    function setAmount(uint256 newAmount) public onlyOwner {
        if(newAmount == 0) revert AmountIsZero();
        amount = newAmount;
        emit AmountPerClaimUpdated(newAmount);
    }
}

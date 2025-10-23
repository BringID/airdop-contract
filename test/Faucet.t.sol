// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {EthFaucet, TransferFailed, RelayerAddressIsZero, AmountIsZero, SenderIsNotRelayer} from "../src/Faucet.sol";

contract FaucetTest is Test {
    event Claimed(address to, uint256 amount);
    event Withdrawn(address to, uint256 amount);
    event StatusUpdated(bool status);
    event RelayerUpdated(address relayer);
    event AmountPerClaimUpdated(uint256 relayer);

    EthFaucet internal faucet;

    address internal constant RELAYER = address(0xAAAA);
    address internal constant RECIPIENT = address(0xBBBB);
    address internal constant WITHDRAW_DEST = address(0xCCCC);
    uint256 internal constant DEFAULT_AMOUNT = 1 ether;
    uint256 internal constant INITIAL_FAUCET_BALANCE = 10 ether;

    function setUp() public {
        faucet = new EthFaucet();
        faucet.setRelayer(RELAYER);
        faucet.setAmount(DEFAULT_AMOUNT);
        vm.deal(address(faucet), INITIAL_FAUCET_BALANCE);
    }

    function testSetStatusUpdatesRunningAndEmitsEvent() public {
        vm.expectEmit(false, false, false, true, address(faucet));
        emit StatusUpdated(true);
        faucet.setStatus(true);
        assertTrue(faucet.running());

        vm.expectEmit(false, false, false, true, address(faucet));
        emit StatusUpdated(false);
        faucet.setStatus(false);
        assertFalse(faucet.running());
    }

    function testSetRelayerUpdatesRelayerAndEmitsEvent() public {
        address newRelayer = address(0xABCD);
        vm.expectEmit(false, false, false, true, address(faucet));
        emit RelayerUpdated(newRelayer);
        faucet.setRelayer(newRelayer);
        assertEq(faucet.relayer(), newRelayer);
    }

    function testSetRelayerRevertsWhenAddressZero() public {
        vm.expectRevert(RelayerAddressIsZero.selector);
        faucet.setRelayer(address(0));
    }

    function testSetAmountUpdatesAmountAndEmitsEvent() public {
        uint256 newAmount = 2 ether;
        vm.expectEmit(false, false, false, true, address(faucet));
        emit AmountPerClaimUpdated(newAmount);
        faucet.setAmount(newAmount);
        assertEq(faucet.amount(), newAmount);
    }

    function testSetAmountRevertsWhenZero() public {
        vm.expectRevert(AmountIsZero.selector);
        faucet.setAmount(0);
    }

    function testClaimTransfersConfiguredAmountAndEmitsEvent() public {
        uint256 recipientBefore = RECIPIENT.balance;

        vm.expectEmit(false, false, false, true, address(faucet));
        emit Claimed(RECIPIENT, DEFAULT_AMOUNT);

        vm.prank(RELAYER);
        faucet.claim(RECIPIENT);

        assertEq(RECIPIENT.balance - recipientBefore, DEFAULT_AMOUNT);
        assertEq(address(faucet).balance, INITIAL_FAUCET_BALANCE - DEFAULT_AMOUNT);
    }

    function testClaimRevertsWhenCallerNotRelayer() public {
        vm.expectRevert(SenderIsNotRelayer.selector);
        faucet.claim(RECIPIENT);
    }

    function testClaimRevertsWhenTransferFails() public {
        uint256 failingAmount = INITIAL_FAUCET_BALANCE + 1 ether;
        faucet.setAmount(failingAmount);

        vm.expectRevert(TransferFailed.selector);
        vm.prank(RELAYER);
        faucet.claim(RECIPIENT);
    }

    function testWithdrawSendsFundsAndEmitsEvent() public {
        uint256 amountToWithdraw = 3 ether;
        faucet.setAmount(amountToWithdraw);
        uint256 beforeBalance = WITHDRAW_DEST.balance;

        vm.expectEmit(false, false, false, true, address(faucet));
        emit Withdrawn(WITHDRAW_DEST, amountToWithdraw);
        faucet.withdraw(WITHDRAW_DEST, amountToWithdraw);

        assertEq(WITHDRAW_DEST.balance - beforeBalance, amountToWithdraw);
        assertEq(address(faucet).balance, INITIAL_FAUCET_BALANCE - amountToWithdraw);
    }

    function testWithdrawRevertsForNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(RELAYER);
        faucet.withdraw(WITHDRAW_DEST, 1 ether);
    }

    function testWithdrawRevertsWhenTransferFails() public {
        uint256 amountToWithdraw = INITIAL_FAUCET_BALANCE + 1 ether;
        faucet.setAmount(amountToWithdraw);

        vm.expectRevert(TransferFailed.selector);
        faucet.withdraw(WITHDRAW_DEST, amountToWithdraw);
    }
}

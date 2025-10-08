// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {Drop} from "../src/Drop.sol";
import {ICredentialRegistry} from "bringid/ICredentialRegistry.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract MockToken is ERC20("Mock Token", "MOCK", 18) {
    constructor() {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockRegistry is ICredentialRegistry {
    uint256 private _score;

    function setScore(uint256 newScore) external {
        _score = newScore;
    }

    function score(uint256, CredentialGroupProof[] calldata) external view override returns (uint256) {
        return _score;
    }

    function validateProof(uint256, CredentialGroupProof calldata) external pure override {}

    function credentialGroupIsActive(uint256) external pure override returns (bool) {
        return true;
    }

    function credentialGroupScore(uint256) external pure override returns (uint256) {
        return 0;
    }
}

contract DropTest is Test {
    Drop internal drop;
    MockRegistry internal registry;
    MockToken internal token;

    address internal constant USER = address(0xBEEF);
    uint256 internal constant INITIAL_TOKENS = 10_000_000 ether;

    function setUp() public {
        registry = new MockRegistry();
        token = new MockToken();
        drop = new Drop(registry, IERC20(address(token)));

        token.mint(address(drop), INITIAL_TOKENS);
    }

    function testClaimRevertsWhenStopped() public {
        registry.setScore(5);
        vm.expectRevert("Airdrop is stopped");
        drop.claim(USER, _emptyProofs());
    }

    function testClaimRevertsWhenAlreadyClaimed() public {
        registry.setScore(6);
        drop.run();

        drop.claim(USER, _emptyProofs());

        vm.expectRevert("Airdrop was claimed");
        drop.claim(USER, _emptyProofs());
    }

    function testClaimRevertsWithInsufficientScore(uint256 scoreSeed) public {
        uint256 score = bound(scoreSeed, 0, 4);
        registry.setScore(score);
        drop.run();

        vm.expectRevert("Insufficient score");
        drop.claim(USER, _emptyProofs());
    }

    function testFuzzClaimLowTierTransfers100kTokens(uint256 scoreSeed) public {
        uint256 score = bound(scoreSeed, 5, 9);
        registry.setScore(score);
        drop.run();

        uint256 balanceBefore = token.balanceOf(USER);
        drop.claim(USER, _emptyProofs());

        assertEq(token.balanceOf(USER) - balanceBefore, 100_000 ether);
        assertTrue(drop.isClaimed(USER));
        assertEq(drop.claims(), 1);
        assertFalse(drop.stopped());
    }

    function testFuzzClaimMidTierTransfers500kTokens(uint256 scoreSeed) public {
        uint256 score = bound(scoreSeed, 10, 19);
        registry.setScore(score);
        drop.run();

        uint256 balanceBefore = token.balanceOf(USER);
        drop.claim(USER, _emptyProofs());

        assertEq(token.balanceOf(USER) - balanceBefore, 500_000 ether);
        assertEq(drop.claims(), 1);
    }

    function testFuzzClaimHighTierTransfers2_5MTokens(uint256 scoreSeed) public {
        uint256 score = bound(scoreSeed, 20, type(uint256).max);
        registry.setScore(score);
        drop.run();

        uint256 balanceBefore = token.balanceOf(USER);
        drop.claim(USER, _emptyProofs());

        assertEq(token.balanceOf(USER) - balanceBefore, 2_500_000 ether);
        assertEq(drop.claims(), 1);
    }

    function testClaimStopsWhenTokensDepleted() public {
        MockRegistry lowRegistry = new MockRegistry();
        MockToken lowToken = new MockToken();
        Drop lowDrop = new Drop(lowRegistry, IERC20(address(lowToken)));

        lowToken.mint(address(lowDrop), 1_000 ether);

        lowRegistry.setScore(25);
        lowDrop.run();

        uint256 userBefore = lowToken.balanceOf(USER);
        lowDrop.claim(USER, _emptyProofs());

        assertEq(lowToken.balanceOf(USER) - userBefore, 1_000 ether);
        assertEq(lowToken.balanceOf(address(lowDrop)), 0);
        assertTrue(lowDrop.isClaimed(USER));
        assertTrue(lowDrop.stopped());
        assertEq(lowDrop.claims(), 1);
    }

    function testRetrieveTransfersAllTokensToOwner() public {
        uint256 ownerBefore = token.balanceOf(address(this));

        drop.retrieve();

        assertEq(token.balanceOf(address(this)) - ownerBefore, INITIAL_TOKENS);
        assertEq(token.balanceOf(address(drop)), 0);
        assertTrue(drop.stopped());
    }

    function testRetrieveRevertsForNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        drop.retrieve();
    }

    function testRunOnlyOwnerCanStartDrop() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        drop.run();

        drop.run();
        assertFalse(drop.stopped());
    }

    function _emptyProofs() internal pure returns (ICredentialRegistry.CredentialGroupProof[] memory proofs) {
        proofs = new ICredentialRegistry.CredentialGroupProof[](0);
    }
}

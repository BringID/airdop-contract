// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ICredentialRegistry} from "bringid/ICredentialRegistry.sol";
import {Ownable, Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract Drop is Ownable2Step {
    ICredentialRegistry public immutable REGISTRY;
    IERC20 public immutable TOKEN;

    mapping(address => bool) public isClaimed;
    uint256 public claims;
    bool public stopped = true;

    constructor(
        ICredentialRegistry registry,
        IERC20 token
    ) Ownable() {
        REGISTRY = registry;
        TOKEN = token;
    }

    function claim(
        address to,
        ICredentialRegistry.CredentialGroupProof[] calldata proofs
    ) public {
        require(!isClaimed[to], "Airdrop was claimed");
        require(!stopped, "Airdrop is stopped");

        uint256 totalScore = REGISTRY.score(0, proofs);
        require(totalScore >= 5, "Insufficient score");

        uint256 amount;
        if (totalScore < 10) {
            amount = 100_000;
        } else if (totalScore < 20) {
            amount = 500_000;
        } else {
            amount = 2_500_000;
        }
        amount *= 1 ether;

        isClaimed[to] = true;

        uint256 tokensAvailable = TOKEN.balanceOf(address(this));
        if (amount >= tokensAvailable) {
            amount = tokensAvailable;
            stopped = true;
        }

        claims++;

        require(
            TOKEN.transfer(to, amount),
            "Token transfer failed"
        );
    }

    // ONLY OWNER //
    function retrieve() public onlyOwner {
        stopped = true;
        uint256 amount = TOKEN.balanceOf(address(this));
        TOKEN.transfer(owner(), amount);
    }

    function run() public onlyOwner {
        stopped = false;
    }
}

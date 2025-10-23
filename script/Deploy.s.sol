// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Drop} from "../src/Drop.sol";
import {ICredentialRegistry} from "bringid/ICredentialRegistry.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";
import "../src/Faucet.sol";
import {EthDrop} from "../src/EthDrop.sol";

contract DeployFaucet is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            EthFaucet F = new EthFaucet();
            F.transferOwnership(0xBB3D568d557857Ca77772476Ad6edEE88A9BB430);
        vm.stopBroadcast();

        console.log("EthFaucet:", address(F));
    }
}

contract DeployFaucetMainnet is Script {
    function run() public {
        address CR = vm.envOr("CREDENTIAL_REGISTRY_ADDRESS", address(0));
        require(CR != address(0), "CREDENTIAL_REGISTRY_ADDRESS should be provided");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            EthDrop ED = new EthDrop(ICredentialRegistry(CR));

            ED.transferOwnership(0xBB3D568d557857Ca77772476Ad6edEE88A9BB430);
        vm.stopBroadcast();

        console.log("EthFaucet:", address(ED));
    }
}

contract DeployTopupRun is Script {
    function run() public {
        // Assume registry is already deployed - get from environment or use hardcoded address
        address registryAddress = vm.envOr("CREDENTIAL_REGISTRY_ADDRESS", address(0));
        require(registryAddress != address(0), "CREDENTIAL_REGISTRY_ADDRESS must be set");

        address token = vm.envOr("TOKEN", address(0));
        require(token != address(0), "TOKEN must be set");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            Drop drop = new Drop(
                ICredentialRegistry(registryAddress),
                IERC20(token)
            );
            IERC20(token).transfer(address(drop), 50_000_000 * 1 ether);
            drop.run();
        vm.stopBroadcast();

        console.log("Drop:", address(drop));
    }
}

contract Deploy is Script {
    function run() public {
        address registryAddress = vm.envOr("CREDENTIAL_REGISTRY_ADDRESS", address(0));
        require(registryAddress != address(0), "CREDENTIAL_REGISTRY_ADDRESS must be set");

        address token = vm.envOr("TOKEN", address(0));
        require(token != address(0), "TOKEN must be set");
        require(token == 0x02E739740B007bd5E4600b9736A143b6E794D223, "TOKEN is wrong");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
            Drop drop = new Drop(
                ICredentialRegistry(registryAddress),
                IERC20(token)
            );
            drop.transferOwnership(0xBB3D568d557857Ca77772476Ad6edEE88A9BB430);
        vm.stopBroadcast();

        console.log("Drop:", address(drop));
    }
}
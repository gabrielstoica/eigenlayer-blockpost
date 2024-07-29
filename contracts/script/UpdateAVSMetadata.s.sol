// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import { Script } from "forge-std/Script.sol";
import { BlockpostServiceManager } from "../src/BlockpostServiceManager.sol";

contract UpdateAVSMetadata is Script {
    function run(address avs, string memory metadata) public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployer);

        BlockpostServiceManager(avs).updateAVSMetadataURI(metadata);

        vm.stopBroadcast();
    }
}

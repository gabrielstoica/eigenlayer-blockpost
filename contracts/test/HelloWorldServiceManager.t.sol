// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "../src/BlockpostServiceManager.sol" as bsm;
import { BlockpostServiceManager } from "../src/BlockpostServiceManager.sol";
import { MockAVSDeployer } from "@eigenlayer-middleware/test/utils/MockAVSDeployer.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BlockpostServiceManagerTest is MockAVSDeployer {
/*   bsm.BlockpostServiceManager sm;
    bsm.BlockpostServiceManager smImplementation;
    BlockpostServiceManager tm;
    BlockpostServiceManager tmImplementation;

    address operator = address(uint160(uint256(keccak256(abi.encodePacked("operator")))));
    address generator = address(uint160(uint256(keccak256(abi.encodePacked("generator")))));

    function setUp() public {
        _setUpBLSMockAVSDeployer();

        tmImplementation = new BlockpostServiceManager(bsm.IRegistryCoordinator(address(registryCoordinator)));

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        tm = BlockpostServiceManager(
            address(
                new TransparentUpgradeableProxy(
                    address(tmImplementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(tm.initialize.selector, pauserRegistry, registryCoordinatorOwner)
                )
            )
        );
    }

    function testCreateNewTask() public {
        cheats.prank(generator, generator);
        tm.createNewTask("world");
        assertEq(tm.latestTaskNum(), 1);
    } */
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import { IDelegationManager } from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import { IAVSDirectory } from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import { IStrategyManager, IStrategy } from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import { StrategyBase } from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import { ECDSAStakeRegistry } from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import { Quorum, StrategyParams } from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import { BlockpostServiceManager } from "../src/BlockpostServiceManager.sol";
import "@eigenlayer/test/mocks/EmptyContract.sol";
import "../src/ERC20Mock.sol";
import "forge-std/Script.sol";
import { Utils } from "./utils/Utils.sol";

contract HoleskyDeployer is Script, Utils {
    // ERC20 and Strategy: we need to deploy this erc20, create a strategy for it, and whitelist this strategy in the strategy manager

    ERC20Mock public erc20Mock;
    StrategyBase public erc20MockStrategy;

    // Hello World contracts
    ProxyAdmin public blockpostProxyAdmin;
    PauserRegistry public blockpostPauserReg;

    ECDSAStakeRegistry public stakeRegistryProxy;
    ECDSAStakeRegistry public stakeRegistryImplementation;

    BlockpostServiceManager public blockpostServiceManagerProxy;
    BlockpostServiceManager public blockpostServiceManagerImplementation;

    function run(string memory _avsMetadatURI) external {
        // Manually pasted addresses of Eigenlayer contracts
        address delegationManagerAddr = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
        address avsDirectoryAddr = 0x055733000064333CaDDbC92763c58BF0192fFeBf;
        address baseStrategyImplementationAddr = 0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9;

        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddr);
        IAVSDirectory avsDirectory = IAVSDirectory(avsDirectoryAddr);
        StrategyBase baseStrategyImplementation = StrategyBase(baseStrategyImplementationAddr);

        address blockpostCommunityMultisig = msg.sender;
        address blockpostPauser = msg.sender;

        vm.startBroadcast();
        _deployBlockpostContracts(
            delegationManager,
            avsDirectory,
            baseStrategyImplementation,
            blockpostCommunityMultisig,
            blockpostPauser,
            _avsMetadatURI
        );
        vm.stopBroadcast();
    }

    function _deployBlockpostContracts(
        IDelegationManager delegationManager,
        IAVSDirectory avsDirectory,
        IStrategy baseStrategyImplementation,
        address blockpostCommunityMultisig,
        address blockpostPauser,
        string memory _avsMetadatURI
    ) internal {
        // Deploy proxy admin for ability to upgrade proxy contracts
        blockpostProxyAdmin = new ProxyAdmin();

        // Deploy pauser registry
        {
            address[] memory pausers = new address[](2);
            pausers[0] = blockpostPauser;
            pausers[1] = blockpostCommunityMultisig;
            blockpostPauserReg = new PauserRegistry(pausers, blockpostCommunityMultisig);
        }

        EmptyContract emptyContract = new EmptyContract();

        // First, deploy upgradeable proxy contracts that will point to the implementations.
        blockpostServiceManagerProxy = BlockpostServiceManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(blockpostProxyAdmin), ""))
        );
        stakeRegistryProxy = ECDSAStakeRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(blockpostProxyAdmin), ""))
        );

        // Second, deploy the implementation contracts, using the proxy contracts as inputs
        {
            stakeRegistryImplementation = new ECDSAStakeRegistry(delegationManager);

            blockpostProxyAdmin.upgrade(
                TransparentUpgradeableProxy(payable(address(stakeRegistryProxy))), address(stakeRegistryImplementation)
            );
        }

        {
            // Create an array with one StrategyParams element
            StrategyParams memory strategyParams =
                StrategyParams({ strategy: baseStrategyImplementation, multiplier: 10_000 });

            StrategyParams[] memory quorumsStrategyParams = new StrategyParams[](1);
            quorumsStrategyParams[0] = strategyParams;

            Quorum memory quorum = Quorum(quorumsStrategyParams);

            // Sort the array (though it has only one element, it's trivially sorted)
            // If the array had more elements, you would need to ensure it is sorted by strategy address

            blockpostProxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(stakeRegistryProxy))),
                address(stakeRegistryImplementation),
                abi.encodeWithSelector(
                    ECDSAStakeRegistry.initialize.selector, address(blockpostServiceManagerProxy), 1, quorum
                )
            );
        }

        blockpostServiceManagerImplementation = new BlockpostServiceManager(
            address(avsDirectory), address(stakeRegistryProxy), address(delegationManager), _avsMetadatURI
        );
        // Upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        blockpostProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blockpostServiceManagerProxy))),
            address(blockpostServiceManagerImplementation)
        );

        // WRITE JSON DATA
        string memory parent_object = "parent object";

        string memory deployed_addresses = "addresses";
        vm.serializeAddress(deployed_addresses, "BlockpostServiceManagerProxy", address(blockpostServiceManagerProxy));
        vm.serializeAddress(
            deployed_addresses, "BlockpostServiceManagerImplementation", address(blockpostServiceManagerImplementation)
        );
        vm.serializeAddress(deployed_addresses, "ECDSAStakeRegistry", address(stakeRegistryProxy));

        string memory deployed_addresses_output = vm.serializeAddress(
            deployed_addresses, "ECDSAStakeRegistryImplementation", address(stakeRegistryImplementation)
        );

        // Serialize all the data
        string memory finalJson = vm.serializeString(parent_object, deployed_addresses, deployed_addresses_output);

        writeOutput(finalJson, "blockpost_avs_holesky_deployment_output");
    }
}

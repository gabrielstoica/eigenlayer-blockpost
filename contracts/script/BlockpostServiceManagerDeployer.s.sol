// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import { IDelegationManager } from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import { IAVSDirectory } from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import { IStrategyManager, IStrategy } from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import { StrategyBaseTVLLimits } from "@eigenlayer/contracts/strategies/StrategyBaseTVLLimits.sol";
import "@eigenlayer/test/mocks/EmptyContract.sol";

import { ECDSAStakeRegistry } from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import { Quorum, StrategyParams } from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";

import { BlockpostServiceManager } from "../src/BlockpostServiceManager.sol";
import "../src/ERC20Mock.sol";

import { Utils } from "./utils/Utils.sol";

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// # To deploy and verify our contract
// forge script script/BlockpostServiceManagerDeployer.s.sol:BlockpostServiceManagerDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract BlockpostServiceManagerDeployer is Script, Utils {
    // ERC20 and Strategy: we need to deploy this erc20, create a strategy for it, and whitelist this strategy in the strategymanager

    ERC20Mock public erc20Mock;
    StrategyBaseTVLLimits public erc20MockStrategy;

    // Blockpost contracts
    ProxyAdmin public blockpostProxyAdmin;
    PauserRegistry public blockpostPauserReg;

    ECDSAStakeRegistry public stakeRegistryProxy;
    ECDSAStakeRegistry public stakeRegistryImplementation;

    BlockpostServiceManager public BlockpostServiceManagerProxy;
    BlockpostServiceManager public BlockpostServiceManagerImplementation;

    function run() external {
        // Eigenlayer contracts
        string memory eigenlayerDeployedContracts = readOutput("eigenlayer_deployment_output");
        IStrategyManager strategyManager =
            IStrategyManager(stdJson.readAddress(eigenlayerDeployedContracts, ".addresses.strategyManager"));
        IDelegationManager delegationManager =
            IDelegationManager(stdJson.readAddress(eigenlayerDeployedContracts, ".addresses.delegation"));
        IAVSDirectory avsDirectory =
            IAVSDirectory(stdJson.readAddress(eigenlayerDeployedContracts, ".addresses.avsDirectory"));
        ProxyAdmin eigenLayerProxyAdmin =
            ProxyAdmin(stdJson.readAddress(eigenlayerDeployedContracts, ".addresses.eigenLayerProxyAdmin"));
        PauserRegistry eigenLayerPauserReg =
            PauserRegistry(stdJson.readAddress(eigenlayerDeployedContracts, ".addresses.eigenLayerPauserReg"));
        StrategyBaseTVLLimits baseStrategyImplementation = StrategyBaseTVLLimits(
            stdJson.readAddress(eigenlayerDeployedContracts, ".addresses.baseStrategyImplementation")
        );

        address blockpostCommunityMultisig = msg.sender;
        address blockpostPauser = msg.sender;

        vm.startBroadcast();
        _deployErc20AndStrategyAndWhitelistStrategy(
            eigenLayerProxyAdmin, eigenLayerPauserReg, baseStrategyImplementation, strategyManager
        );
        _deployBlockpostContracts(
            delegationManager, avsDirectory, erc20MockStrategy, blockpostCommunityMultisig, blockpostPauser
        );
        vm.stopBroadcast();
    }

    function _deployErc20AndStrategyAndWhitelistStrategy(
        ProxyAdmin eigenLayerProxyAdmin,
        PauserRegistry eigenLayerPauserReg,
        StrategyBaseTVLLimits baseStrategyImplementation,
        IStrategyManager strategyManager
    ) internal {
        erc20Mock = new ERC20Mock();
        // TODO(samlaf): any reason why we are using the strategybase with tvl limits instead of just using strategybase?
        // the maxPerDeposit and maxDeposits below are just arbitrary values.
        erc20MockStrategy = StrategyBaseTVLLimits(
            address(
                new TransparentUpgradeableProxy(
                    address(baseStrategyImplementation),
                    address(eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBaseTVLLimits.initialize.selector,
                        1 ether, // maxPerDeposit
                        100 ether, // maxDeposits
                        IERC20(erc20Mock),
                        eigenLayerPauserReg
                    )
                )
            )
        );
        IStrategy[] memory strats = new IStrategy[](1);
        strats[0] = erc20MockStrategy;
        bool[] memory thirdPartyTransfersForbiddenValues = new bool[](1);
        thirdPartyTransfersForbiddenValues[0] = false;
        strategyManager.addStrategiesToDepositWhitelist(strats, thirdPartyTransfersForbiddenValues);
    }

    function _deployBlockpostContracts(
        IDelegationManager delegationManager,
        IAVSDirectory avsDirectory,
        IStrategy strat,
        address blockpostCommunityMultisig,
        address blockpostPauser
    ) internal {
        // Adding this as a temporary fix to make the rest of the script work with a single strategy
        // since it was originally written to work with an array of strategies
        IStrategy[1] memory deployedStrategyArray = [strat];
        uint256 numStrategies = deployedStrategyArray.length;

        // deploy proxy admin for ability to upgrade proxy contracts
        blockpostProxyAdmin = new ProxyAdmin();

        // deploy pauser registry
        {
            address[] memory pausers = new address[](2);
            pausers[0] = blockpostPauser;
            pausers[1] = blockpostCommunityMultisig;
            blockpostPauserReg = new PauserRegistry(pausers, blockpostCommunityMultisig);
        }

        EmptyContract emptyContract = new EmptyContract();

        // hard-coded inputs

        /**
         * First, deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        BlockpostServiceManagerProxy = BlockpostServiceManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(blockpostProxyAdmin), ""))
        );
        stakeRegistryProxy = ECDSAStakeRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(blockpostProxyAdmin), ""))
        );

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        {
            stakeRegistryImplementation = new ECDSAStakeRegistry(delegationManager);

            blockpostProxyAdmin.upgrade(
                TransparentUpgradeableProxy(payable(address(stakeRegistryProxy))), address(stakeRegistryImplementation)
            );
        }

        {
            StrategyParams[] memory quorumsStrategyParams = new StrategyParams[](numStrategies);

            for (uint256 j = 0; j < numStrategies; j++) {
                quorumsStrategyParams[j] = StrategyParams({ strategy: deployedStrategyArray[j], multiplier: 10_000 });
            }

            Quorum memory quorum = Quorum(quorumsStrategyParams);

            blockpostProxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(stakeRegistryProxy))),
                address(stakeRegistryImplementation),
                abi.encodeWithSelector(
                    ECDSAStakeRegistry.initialize.selector, address(BlockpostServiceManagerProxy), 1, quorum
                )
            );
        }

        BlockpostServiceManagerImplementation = new BlockpostServiceManager(
            address(avsDirectory),
            address(stakeRegistryProxy),
            address(delegationManager),
            "https://api.npoint.io/ba1dd2199b47913067d1"
        );
        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        blockpostProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(BlockpostServiceManagerProxy))),
            address(BlockpostServiceManagerImplementation)
        );

        // WRITE JSON DATA
        string memory parent_object = "parent object";

        string memory deployed_addresses = "addresses";
        vm.serializeAddress(deployed_addresses, "erc20Mock", address(erc20Mock));
        vm.serializeAddress(deployed_addresses, "erc20MockStrategy", address(erc20MockStrategy));
        vm.serializeAddress(deployed_addresses, "BlockpostServiceManagerProxy", address(BlockpostServiceManagerProxy));
        vm.serializeAddress(
            deployed_addresses, "BlockpostServiceManagerImplementation", address(BlockpostServiceManagerImplementation)
        );
        vm.serializeAddress(deployed_addresses, "ECDSAStakeRegistry", address(stakeRegistryProxy));

        string memory deployed_addresses_output = vm.serializeAddress(
            deployed_addresses, "ECDSAStakeRegistryImplementation", address(stakeRegistryImplementation)
        );

        // serialize all the data
        string memory finalJson = vm.serializeString(parent_object, deployed_addresses, deployed_addresses_output);

        writeOutput(finalJson, "blockpost_avs_deployment_output");
    }
}

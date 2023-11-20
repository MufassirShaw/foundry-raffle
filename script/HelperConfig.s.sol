// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 enteranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subcriptionId;
        uint32 callbackGasLimit;
        address link;
    }
    NetworkConfig public activeConfig;

    constructor() {
        if (block.chainid == 1115511) {
            activeConfig = getSepoliaEthConfig();
        } else {
            activeConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                enteranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subcriptionId: 5798,
                callbackGasLimit: 50000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeConfig.vrfCoordinator != address(0)) {
            return activeConfig;
        }
        uint96 baseFee = 0.25 ether; // 0.25 Link
        uint96 gasFee = 1e18; // 1 gwei

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
            baseFee,
            gasFee
        );
        vm.stopBroadcast();
        LinkToken link = new LinkToken();
        return
            NetworkConfig({
                enteranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinator),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subcriptionId: 0,
                callbackGasLimit: 50000,
                link: address(link)
            });
    }
}

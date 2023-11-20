// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";
import {Raffle} from "../src/Raffle.sol";

contract RaffleDeploy is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 enteranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subcriptionId,
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.activeConfig();

        if (subcriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subcriptionId = createSubscription.createSubscription(
                vrfCoordinator
            );

            // fund subcription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subcriptionId,
                link
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            enteranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subcriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();

        addConsumer.addConsumer(address(raffle), vrfCoordinator, subcriptionId);

        return (raffle, helperConfig);
    }
}

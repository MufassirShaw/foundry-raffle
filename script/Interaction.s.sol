// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() private returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ) = helperConfig.activeConfig();

        return createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint64 subscriptionId) {
        console.log("Creating subscription id on chain", block.chainid);
        vm.startBroadcast();
        subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription id is ", subscriptionId);
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 4 ether;

    function fundSubscriptionUsingConfig() private returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subcriptionId,
            ,
            address link
        ) = helperConfig.activeConfig();

        return fundSubscription(vrfCoordinator, subcriptionId, link);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link
    ) public returns (uint64 subscriptionId) {
        console.log("using vrf-coordinator", vrfCoordinator);
        console.log("using subId", subId);
        console.log("using link", link);
        console.log("Creating subscription id on chain", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
        console.log("Your subscription id is ", subscriptionId);
    }

    function run() external returns (uint64) {
        return fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address consumer,
        address vrfCoordinator,
        uint64 subId
    ) public {
        console.log("Adding consumer", consumer);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("Using subId", subId);

        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address consumer) public {
        HelperConfig helperConfig = new HelperConfig();

        (, , address vrfCoordinator, , uint64 subcriptionId, , ) = helperConfig
            .activeConfig();

        addConsumer(consumer, vrfCoordinator, subcriptionId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

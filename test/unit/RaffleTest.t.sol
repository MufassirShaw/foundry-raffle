// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {RaffleDeploy} from "../../script/RaffleDeploy.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    /** Events */

    event EnteredRaffle(address indexed player);
    Raffle raffle;
    HelperConfig helperConfig;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subcriptionId;
    uint32 callbackGasLimit;
    address link;

    function setUp() external {
        RaffleDeploy deployRaffle = new RaffleDeploy();

        (raffle, helperConfig) = deployRaffle.run();

        (
            enteranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subcriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeConfig();

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleExpectRevertWithNoEnoughEth() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRafflePlayerRecordedOnEntrace() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testRaffleExpectEventEmitted() public {
        vm.startPrank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testRaffleNotOpen() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1); // `wrap` sets block time
        vm.roll(block.number + 1); // go to the next block
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }
}

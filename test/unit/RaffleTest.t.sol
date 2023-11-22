// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

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
    event RequestedRaffleWinner(uint256 indexed requestId);
    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subcriptionId;
    uint32 callbackGasLimit;
    address link;

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1); // `wrap` sets block time
        vm.roll(block.number + 1); // go to the next block
        _;
    }

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

    function testRaffleNotOpen() public raffleEnteredAndTimePassed {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    ////////////////
    // CheckUpKeep //
    ////////////////

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1); // `wrap` sets block time
        vm.roll(block.number + 1); // go to the next block

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfItIsNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        // act
        raffle.performUpkeep("");
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        //assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        // arrange
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();

        // act
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        //assert
        assert(!upKeepNeeded);
    }

    ///////////////////
    // PerformUpKeep //
    ///////////////////

    function testPerformKeepDoesNotRevertIfUpKeepNeeded()
        public
        raffleEnteredAndTimePassed
    {
        // act
        raffle.performUpkeep("");
    }

    function testPerformKeepRevertsIfUpKeepNotNeeded() public {
        //arrange
        uint256 balance = 0;
        uint256 players = 0;
        uint256 raffleState = uint256(Raffle.RaffleState.OPEN);

        // act/assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpKeepNotNeeded.selector,
                balance,
                players,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformKeepRaffleUpdatesAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        // assert
        assert(uint256(requestId) > 0);
        assert(uint256(raffle.getRaffleState()) == 1);
    }

    ///////////////////////
    // fulfillRandomWords //
    ///////////////////////

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 requestId
    ) public raffleEnteredAndTimePassed {
        // Arrange

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    function testFullFillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
    {
        // Arrange
        uint256 additionalEntrances = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: enteranceFee}();
        }

        uint256 startingTimeStamp = raffle.getRaffleLastTimeStamp();
        uint256 startingBalance = raffle.getPlayer(0).balance;

        //act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        uint256 endingTimeStamp = raffle.getRaffleLastTimeStamp();

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getNumOfPlayer() == 0);

        assert(endingTimeStamp > startingTimeStamp);
        address recentWinner = raffle.s_recentWinner();
        uint256 prize = enteranceFee * (additionalEntrances + 1);
        uint256 winnerEndingBalance = recentWinner.balance;

        console.log("winnerEndingBalance", winnerEndingBalance);
        console.log("prize", prize + startingBalance);

        assert(prize + startingBalance == winnerEndingBalance);
    }
}

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/// @title A simple Raffle contract
/// @author Mufassir shah
/// @notice This contract is for creating a simple raffle
/// @dev Uses Chainlink VRFv2 and Chainlink automation

contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEthSent();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpKeepNotNeeded(
        uint256 balance,
        uint256 players,
        uint256 raffleState
    );
    error Raffle_NotEnoughTimePassed();
    /** Type Declartion */

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_interval; // duration of the lottery in secs
    address[] private s_players;
    uint256 private s_lastTimeStamp;
    address public s_recentWinner;
    RaffleState private s_raffleState;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subcriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATION = 2;
    uint32 private constant NUM_WORDS = 2;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 enteranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subcriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subcriptionId = subcriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_enteranceFee) {
            revert Raffle_NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /** 
      * @dev This is function the Chainlink Automation nodes call
      * to see if it's time to call an upkeep
      * This following should be true for this to return true
        1. The time interval has passed b/w raffle runs
        2. The raffle is in OPEN state
        3. The contract has enough ETH
        4. The subcription is funded with LINK
     */
    function checkUpKeep(
        bytes memory /* calldata*/
    ) public view returns (bool upKeepNeeded, bytes memory /*performData */) {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasEth = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upKeepNeeded = (timeHasPassed && isOpen && hasEth && hasPlayers);
        return (upKeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData */) external {
        // check to see if enough time has passed
        (bool upKeepNeeded, ) = checkUpKeep("");

        if (!upKeepNeeded) {
            revert Raffle_UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle_NotEnoughTimePassed();
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subcriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );

        if (!success) {
            ///
            revert Raffle_TransferFailed();
        }

        emit PickedWinner(s_recentWinner);
    }

    /** Getter function */
    function getEnteranceFee() public view returns (uint256 fee) {
        fee = i_enteranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getNumOfPlayer() external view returns (uint256) {
        return s_players.length;
    }

    function getRaffleLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}

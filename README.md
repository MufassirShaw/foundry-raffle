# Provably Random Raffle Contracts  

## About

This code is to create a provably random smart contract lottery.

## What we want to do?

1. Users can enter by paying for a ticket.
    1. The ticket fees are gonna go to the winner during the draw
2. After X amount of time, the lottery will automatically draw a winner.
    1. And this will be done programmatically.
3. Using Chainlink VRF & Chainlink Automation
    1. Chainlink VRF -> Randomness
    2. Chainlink Automation -> Time based trigger

## Test

1. Write deploy scripts
2. Write tests
    1. Work on chain
    2. Forked testnet
    3. Forked mainnet

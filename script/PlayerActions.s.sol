// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/BaccaratGame.sol";

/// @title PlayerActions Script
/// @notice Script contract for interacting with the BaccaratGame contract
/// @dev Uses Forge's Script contract for deployment and interaction
contract PlayerActions is Script {
    /// @notice Instance of the BaccaratGame contract
    BaccaratGame public game;

    /// @notice Initializes the script by setting up the game contract instance
    /// @dev Replace BACCARAT_ADDRESS with the actual deployed contract address before running
    function setUp() public {
        // Option 1: Using environment variable
        address baccaratAddress = vm.envAddress("BACCARAT_ADDRESS");
        game = BaccaratGame(baccaratAddress);

        // Option 2 (alternative): Hardcoded address
        // game = BaccaratGame(0x1234...); // Replace with your actual deployed address
    }

    /// @notice Places a bet on the Player position
    /// @dev Broadcasts a transaction with 0.1 ETH as the bet amount
    function placeBetOnPlayer() public {
        vm.startBroadcast();
        game.placeBet{value: 0.1 ether}(BaccaratGame.BetType.PLAYER);
        vm.stopBroadcast();
    }

    /// @notice Places a bet on the Banker position
    /// @dev Broadcasts a transaction with 0.1 ETH as the bet amount
    function placeBetOnBanker() public {
        vm.startBroadcast();
        game.placeBet{value: 0.1 ether}(BaccaratGame.BetType.BANKER);
        vm.stopBroadcast();
    }

    /// @notice Places a bet on a Tie
    /// @dev Broadcasts a transaction with 0.1 ETH as the bet amount
    function placeBetOnTie() public {
        vm.startBroadcast();
        game.placeBet{value: 0.1 ether}(BaccaratGame.BetType.TIE);
        vm.stopBroadcast();
    }

    /// @notice Retrieves the current bet of the caller
    /// @return uint256 The bet amount
    /// @return uint8 The bet type (0 for Player, 1 for Banker, 2 for Tie)
    function checkMyBet() public view returns (uint256, uint8) {
        BaccaratGame.Bet memory bet = game.getPlayerBet(msg.sender);
        return (bet.amount, uint8(bet.betType));
    }

    /// @notice Checks the current state of the game
    /// @return uint8 The game state as an unsigned integer
    function checkGameState() public view returns (uint8) {
        return uint8(game.getGameState());
    }

    /// @notice Views the current cards in both Player and Banker hands
    /// @return Two uint8 arrays representing the Player's and Banker's hands respectively
    function viewCurrentHands()
        public
        view
        returns (uint8[] memory, uint8[] memory)
    {
        (
            BaccaratGame.Hand memory playerHand,
            BaccaratGame.Hand memory bankerHand
        ) = game.getCurrentHands();

        // Create arrays of the correct size based on number of cards in each hand
        uint8[] memory playerCards = new uint8[](playerHand.numCards);
        uint8[] memory bankerCards = new uint8[](bankerHand.numCards);

        // Copy cards from hands to arrays
        for (uint8 i = 0; i < playerHand.numCards; i++) {
            playerCards[i] = playerHand.cards[i];
        }
        for (uint8 i = 0; i < bankerHand.numCards; i++) {
            bankerCards[i] = bankerHand.cards[i];
        }

        return (playerCards, bankerCards);
    }

    /// @notice Gets the betting time remaining
    function getBettingTimeRemaining() public view returns (uint256) {
        return game.getBettingTimeRemaining();
    }

    /// @notice Checks if betting is currently open
    function isBettingOpen() public view returns (bool) {
        return game.isBettingOpen();
    }

    /// @notice Gets potential winnings for a bet
    /// @param betType The type of bet
    /// @param amount The bet amount
    function getPotentialWinnings(
        BaccaratGame.BetType betType,
        uint256 amount
    ) public view returns (uint256) {
        return game.calculatePotentialWinnings(betType, amount);
    }

    /// @notice Places a bet with validation
    /// @param betType The type of bet
    /// @param amount The amount to bet in ether
    function placeBetWithValidation(
        BaccaratGame.BetType betType,
        uint256 amount
    ) public {
        require(game.isBettingOpen(), "Betting is not open");
        (uint256 minBet, uint256 maxBet) = game.getBetLimits();
        require(amount >= minBet && amount <= maxBet, "Invalid bet amount");

        vm.startBroadcast();
        game.placeBet{value: amount}(betType);
        vm.stopBroadcast();
    }
}

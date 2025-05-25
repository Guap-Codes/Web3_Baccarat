// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/BaccaratGame.sol";
import "../src/RandomNumberGenerator.sol";
import "./mocks/MockRandomNumberGenerator.sol";

/// @title Baccarat Game Test Suite
/// @notice Comprehensive test suite for the Baccarat game smart contract
/// @dev Uses Forge testing framework and includes tests for betting, game flow, payouts, and emergency functions
contract BaccaratGameTest is Test {
    // Contract instances
    BaccaratGame public game;
    MockRandomNumberGenerator public rng;

    // Test addresses
    address public owner;
    address public player1;
    address public player2;
    address public player3;

    // Test bet amounts
    uint256 public constant PLAYER1_BET = 1 ether;
    uint256 public constant PLAYER2_BET = 2 ether;
    uint256 public constant PLAYER3_BET = 5 ether;

    // Events for testing
    event BetPlaced(address indexed player, uint256 amount, BaccaratGame.BetType betType);
    event GameStarted();
    event GameEnded(BaccaratGame.BetType winner);
    event WinningsDistributed(address indexed winner, uint256 amount);

    /// @notice Set up the test environment before each test
    /// @dev Deploys contracts, creates test addresses, and funds test accounts
    function setUp() public {
        owner = address(this);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");

        // Deploy mock RNG for controlled testing
        rng = new MockRandomNumberGenerator();

        // Deploy main game contract
        game = new BaccaratGame(address(rng));

        // Fund test accounts with initial balance
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
    }

    /// @notice Test the betting phase functionality
    /// @dev Verifies bet placement and event emission
    function testBettingPhase() public {
        // Test placing valid bets
        vm.startPrank(player1);
        vm.expectEmit(true, true, true, true);
        emit BetPlaced(player1, PLAYER1_BET, BaccaratGame.BetType.PLAYER);
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);
        vm.stopPrank();

        // Verify bet was recorded
        BaccaratGame.Bet memory bet = game.getPlayerBet(player1);
        assertEq(bet.amount, PLAYER1_BET);
        assertEq(uint256(bet.betType), uint256(BaccaratGame.BetType.PLAYER));
    }

    /// @notice Test prevention of double betting
    /// @dev Ensures a player cannot place multiple bets in the same round
    function test_RevertWhen_BetTwice() public {
        vm.startPrank(player1);
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);
        vm.expectRevert("Bet already placed");
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.BANKER);
        vm.stopPrank();
    }

    /// @notice Test betting deadline enforcement
    /// @dev Verifies bets cannot be placed after the betting period ends
    function test_RevertWhen_BetAfterDeadline() public {
        // Advance time beyond betting period
        vm.warp(block.timestamp + game.BETTING_PERIOD() + 1);

        vm.prank(player1);
        vm.expectRevert("Betting period has ended");
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);
    }

    /// @notice Test complete game flow from start to finish
    /// @dev Simulates a full game with multiple players and verifies state transitions
    function testCompleteGameFlow() public {
        // Set the game address in the RNG contract
        rng.setGame(address(game));

        // Place bets
        vm.prank(player1);
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);

        vm.prank(player2);
        game.placeBet{value: PLAYER2_BET}(BaccaratGame.BetType.BANKER);

        // Start game
        vm.expectEmit(true, true, true, true);
        emit GameStarted();
        game.startGame();

        // Simulate RNG callback with predetermined cards
        uint8[4] memory initialCards = [1, 2, 3, 4]; // Example cards
        rng.fulfillRandomRequest(initialCards);

        // Since the initial cards result in a hand that needs a third card
        // (cards [1,2] for player = 3, cards [3,4] for banker = 7),
        // we need to fulfill the additional cards request
        uint8[2] memory additionalCards = [5, 6]; // Additional cards
        rng.fulfillAdditionalRequest(additionalCards);

        // Verify game state
        assertEq(uint256(game.getGameState()), uint256(BaccaratGame.GameState.ENDED));
    }

    /// @notice Test payout calculations for player bets
    /// @dev Verifies correct calculation of winnings for player bets
    function testPayoutCalculation() public view {
        // Test player win payout
        uint256 betAmount = 1 ether;
        uint256 expectedWinnings = betAmount * 2; // 1:1 payout

        uint256 calculatedWinnings = game.calculatePotentialWinnings(BaccaratGame.BetType.PLAYER, betAmount);

        assertEq(calculatedWinnings, expectedWinnings);
    }

    /// @notice Test banker commission calculations
    /// @dev Verifies correct calculation of banker bet winnings including commission
    function testBankerCommission() public view {
        uint256 betAmount = 1 ether;
        uint256 commission = (betAmount * 5) / 100; // 5% commission
        uint256 expectedWinnings = (betAmount * 195) / 100 - commission;

        uint256 calculatedWinnings = game.calculatePotentialWinnings(BaccaratGame.BetType.BANKER, betAmount);

        assertEq(calculatedWinnings, expectedWinnings);
    }

    /// @notice Test hand value calculations
    /// @dev Verifies correct calculation of hand values according to Baccarat rules
    function testHandValueCalculation() public {
        // Set the game address in the RNG contract
        rng.setGame(address(game));

        // Setup a game with known cards
        setupGameWithCards([8, 9, 7, 6]); // Player: 8,9 (7), Banker: 7,6 (3)

        (BaccaratGame.Hand memory playerHand, BaccaratGame.Hand memory bankerHand) = game.getCurrentHands();

        assertEq(playerHand.value, 7); // 8+9 = 17 -> 7
        assertEq(bankerHand.value, 3); // 7+6 = 13 -> 3
    }

    /// @notice Test third card drawing rules
    /// @dev Verifies correct implementation of Baccarat third card rules
    function testThirdCardRules() public {
        // First scenario - test when player needs third card (no naturals)
        setupGameWithCards([2, 3, 3, 4]); // Player: 5 (2+3), Banker: 7 (3+4)
        assertTrue(game.needsThirdCard());

        // Complete the current game by providing the additional cards
        uint8[2] memory additionalCards = [5, 6];
        rng.fulfillAdditionalRequest(additionalCards);

        // Reset game state for second scenario
        vm.prank(owner);
        game.startNewGame();

        // Second scenario - test banker drawing rules
        setupGameWithCards([7, 8, 2, 3]); // Player: 5 (7+8=15→5), Banker: 5 (2+3)
        assertTrue(game.shouldBankerDraw(6)); // Banker should draw with 5 when player's third card is 6
        assertFalse(game.shouldBankerDraw(3)); // Banker should not draw with 5 when player's third card is 3
    }

    /*
    /// @notice Test third card drawing rules
    /// @dev Verifies correct implementation of Baccarat third card rules
    function testThirdCardRules() public {
        // First scenario - test when player needs third card
        setupGameWithCards([2, 3, 4, 5]); // Player: 5, Banker: 9
        assertTrue(game.needsThirdCard());

        // Complete the current game by providing the additional cards
        uint8[2] memory additionalCards = [5, 6];
        rng.fulfillAdditionalRequest(additionalCards);

        // Reset game state for second scenario
        vm.prank(owner);
        game.startNewGame();

        // Second scenario - test banker drawing rules
        setupGameWithCards([7, 8, 2, 3]); // Player: 5, Banker: 5
        assertTrue(game.shouldBankerDraw(6)); // Banker should draw with 5 when player's third card is 6
        assertFalse(game.shouldBankerDraw(3)); // Banker should not draw with 5 when player's third card is 3
    }*/

    /// @notice Test emergency pause functionality
    /// @dev Verifies the contract can be paused and operations are blocked while paused
    function testEmergencyPause() public {
        game.emergencyPause();
        assertTrue(game.paused());

        // Use the custom error type directly
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(player1);
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);
    }

    /// @notice Test game cancellation and refund process
    /// @dev Verifies proper refund of bets and state reset on game cancellation
    function testGameCancellation() public {
        // Place bets
        vm.prank(player1);
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);

        uint256 initialBalance = player1.balance;

        // Cancel game
        game.cancelGame();

        // Verify refund
        assertEq(player1.balance, initialBalance + PLAYER1_BET);
        assertEq(uint256(game.getGameState()), uint256(BaccaratGame.GameState.BETTING));
    }

    /// @notice Helper function to setup a game with predetermined cards
    /// @dev Used by multiple tests to create a consistent game state
    /// @param cards Array of 4 card values to be used in the game
    function setupGameWithCards(uint8[4] memory cards) internal {
        // Set the game address in the RNG contract (if not already set)
        if (address(rng.game()) != address(game)) {
            rng.setGame(address(game));
        }

        vm.prank(player1);
        game.placeBet{value: PLAYER1_BET}(BaccaratGame.BetType.PLAYER);

        game.startGame();
        rng.fulfillRandomRequest(cards);
    }
}

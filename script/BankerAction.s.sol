// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/BaccaratGame.sol";

/// @title Baccarat Game Admin Actions Script
/// @notice Script contract for managing administrative functions of the Baccarat game
/// @dev Uses Forge's Script contract for deployment and transaction management
contract BankerAction is Script {
    BaccaratGame public game;

    /// @notice Initializes the script with the deployed game contract
    /// @dev Must set BACCARAT_ADDRESS to the deployed contract address before running
    function setUp() public {
        // Load address from environment variable
        address baccaratAddress = vm.envAddress("BACCARAT_ADDRESS");
        game = BaccaratGame(baccaratAddress);
    }

    /// @notice Starts a new game round
    /// @dev Broadcasts a transaction to call startGame() on the game contract
    function startNewGame() public {
        vm.startBroadcast();
        game.startGame();
        vm.stopBroadcast();
    }

    /// @notice Resets the current game round
    /// @dev Broadcasts a transaction to call startNewRound() on the game contract
    function resetGameRound() public {
        vm.startBroadcast();
        game.startNewRound();
        vm.stopBroadcast();
    }

    /// @notice Withdraws accumulated house commission
    /// @dev Broadcasts a transaction to withdraw house commission to the owner
    function withdrawCommission() public {
        vm.startBroadcast();
        game.withdrawHouseCommission();
        vm.stopBroadcast();
    }

    /// @notice Pauses all game operations in case of emergency
    /// @dev Broadcasts a transaction to pause the game contract
    function pauseGame() public {
        vm.startBroadcast();
        game.emergencyPause();
        vm.stopBroadcast();
    }

    /// @notice Resumes game operations after emergency pause
    /// @dev Broadcasts a transaction to unpause the game contract
    function unpauseGame() public {
        vm.startBroadcast();
        game.emergencyUnpause();
        vm.stopBroadcast();
    }

    /// @notice Retrieves the total bets placed on each betting option
    /// @dev Returns total bets for Player, Banker, and Tie positions
    /// @return uint256 Total bets on Player
    /// @return uint256 Total bets on Banker
    /// @return uint256 Total bets on Tie
    function checkTotalBets() public view returns (uint256, uint256, uint256) {
        uint256[3] memory bets = game.getCurrentBets();
        return (bets[0], bets[1], bets[2]);
    }
}

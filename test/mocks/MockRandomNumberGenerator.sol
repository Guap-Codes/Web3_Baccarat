// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../src/interfaces/IRandomNumberGenerator.sol";
import "../../src/BaccaratGame.sol";

/// @title Mock Random Number Generator
/// @notice A mock contract for testing random number generation in the Baccarat game
/// @dev Implements IRandomNumberGenerator interface for testing purposes
contract MockRandomNumberGenerator is IRandomNumberGenerator {
    BaccaratGame public game;
    uint256 public currentRequestId;
    mapping(uint256 => bool) public fulfilled;

    /// @notice Sets the Baccarat game contract address
    /// @param _game Address of the BaccaratGame contract
    function setGame(address _game) external {
        game = BaccaratGame(_game);
    }

    /// @notice Mocks the request for initial random numbers
    /// @return currentRequestId The incremented request ID
    function requestRandomNumbers() external returns (uint256) {
        currentRequestId++;
        return currentRequestId;
    }

    /// @notice Mocks the request for additional random numbers
    /// @return currentRequestId The incremented request ID
    function requestAdditionalCards() external returns (uint256) {
        currentRequestId++;
        return currentRequestId;
    }

    /// @notice Mocks the fulfillment of initial random cards request
    /// @param cards Array of 4 cards representing initial deal
    function fulfillRandomRequest(uint8[4] memory cards) external {
        fulfilled[currentRequestId] = true;
        game.receiveInitialCards(currentRequestId, cards);
    }

    /// @notice Mocks the fulfillment of additional cards request
    /// @param cards Array of 2 cards representing additional cards
    function fulfillAdditionalRequest(uint8[2] memory cards) external {
        fulfilled[currentRequestId] = true;
        game.receiveThirdCard(currentRequestId, cards);
    }

    /// @notice Checks if a random number request has been fulfilled
    /// @param requestId The ID of the request to check
    /// @return bool True if the request has been fulfilled
    function isRequestFulfilled(
        uint256 requestId
    ) external view returns (bool) {
        return fulfilled[requestId];
    }

    /// @notice Gets random numbers for a specific request
    /// @param requestId The ID of the request
    /// @return randomWords Array of random numbers
    function getRandomNumbers(
        uint256 requestId
    ) external view returns (uint256[] memory) {
        require(fulfilled[requestId], "Request not fulfilled");
        uint256[] memory randomWords = new uint256[](4); // Default to 4 cards
        // Mock implementation - return dummy values
        for (uint256 i = 0; i < 4; i++) {
            randomWords[i] = i + 1;
        }
        return randomWords;
    }
}

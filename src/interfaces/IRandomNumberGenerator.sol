// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Random Number Generator Interface
/// @notice Interface for generating random numbers for card games
/// @dev This interface should be implemented by contracts that provide random number generation functionality
interface IRandomNumberGenerator {
    /// @notice Requests a new set of random numbers
    /// @return requestId Unique identifier for the random number request
    function requestRandomNumbers() external returns (uint256);

    /// @notice Requests additional random numbers for new cards
    /// @return requestId Unique identifier for the additional cards request
    function requestAdditionalCards() external returns (uint256);

    /// @notice Checks if a random number request has been fulfilled
    /// @param requestId The ID of the request to check
    /// @return bool True if the request has been fulfilled, false otherwise
    function isRequestFulfilled(uint256 requestId) external view returns (bool);

    /// @notice Retrieves the random numbers for a given request
    /// @param requestId The ID of the request to get random numbers for
    /// @return uint256[] Array of random numbers generated for the request
    function getRandomNumbers(uint256 requestId) external view returns (uint256[] memory);
}

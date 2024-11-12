// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IBaccaratGame Interface
/// @notice Interface for the Baccarat game contract that receives random card values
interface IBaccaratGame {
    /// @notice Emitted when random number generator address is updated
    /// @param oldGenerator Previous random number generator address
    /// @param newGenerator New random number generator address
    event RandomNumberGeneratorUpdated(address indexed oldGenerator, address indexed newGenerator);

    /// @notice Emitted when initial cards are received
    /// @param requestId The Chainlink VRF request ID
    /// @param cards The dealt cards
    event InitialCardsReceived(uint256 indexed requestId, uint8[4] cards);

    /// @notice Emitted when third cards are received
    /// @param requestId The Chainlink VRF request ID
    /// @param cards The dealt cards
    event ThirdCardsReceived(uint256 indexed requestId, uint8[2] cards);

    error InvalidRandomNumberGenerator();

    error InvalidRequestId();

    error InvalidCardValue();

    error InvalidGameState();

    /// @notice Callback function to receive initial cards for both player and banker
    /// @param requestId The Chainlink VRF request ID associated with these cards
    /// @param cards Array of 4 cards [player1, player2, banker1, banker2] as values 1-52
    /// @dev Cards are represented as values 1-52, where:
    ///      1-13: Hearts (A-K)
    ///      14-26: Diamonds (A-K)
    ///      27-39: Clubs (A-K)
    ///      40-52: Spades (A-K)
    /// @dev Only callable by the registered random number generator
    function receiveInitialCards(uint256 requestId, uint8[4] memory cards) external;

    /// @notice Callback function to receive potential third cards for player and/or banker
    /// @param requestId The Chainlink VRF request ID associated with these cards
    /// @param cards Array of 2 cards [playerThird, bankerThird] as values 1-52
    /// @dev Not all values in the cards array may be used, depending on the game rules
    ///      The game contract should determine which cards to use based on the current game state
    /// @dev Only callable by the registered random number generator
    function receiveThirdCard(uint256 requestId, uint8[2] memory cards) external;

    /// @notice Sets or updates the random number generator address
    /// @param generator The address of the random number generator contract
    /// @dev Only callable by the contract owner
    function setRandomNumberGenerator(address generator) external;

    /// @notice Returns the current random number generator address
    /// @return The address of the current random number generator
    function getRandomNumberGenerator() external view returns (address);
}

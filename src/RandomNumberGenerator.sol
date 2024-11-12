// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBaccaratGame.sol";

/// @title Random Number Generator for Baccarat Game
/// @notice Provides verifiable random numbers for card dealing in a Baccarat game using Chainlink VRF
/// @dev Inherits from VRFConsumerBaseV2 for Chainlink VRF functionality and Ownable for access control
contract RandomNumberGenerator is VRFConsumerBaseV2, Ownable {
    // Chainlink VRF variables
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    bytes32 private immutable keyHash;
    uint64 private immutable subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint32 private constant INITIAL_NUM_WORDS = 4; // For initial deal
    uint32 private constant ADDITIONAL_NUM_WORDS = 2; // For third card draw

    // Game variables
    address public baccaratGame;
    mapping(uint256 => bool) public requestIdToFulfilled;
    mapping(uint256 => uint256[]) public requestIdToRandomWords;

    // Events
    event RandomNumberRequested(uint256 requestId);
    event RandomNumberFulfilled(uint256 requestId, uint256[] randomWords);
    event BaccaratGameUpdated(address indexed oldGame, address indexed newGame);

    constructor(address _vrfCoordinator, bytes32 _keyHash, uint64 _subscriptionId)
        VRFConsumerBaseV2(_vrfCoordinator)
        Ownable(msg.sender)
    {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    /// @notice Restricts function access to only the Baccarat game contract
    modifier onlyBaccaratGame() {
        require(msg.sender == baccaratGame, "Caller is not the Baccarat game");
        _;
    }

    /// @notice Updates the address of the Baccarat game contract
    /// @param _baccaratGame New Baccarat game contract address
    /// @dev Can only be called by the contract owner
    function setBaccaratGame(address _baccaratGame) external onlyOwner {
        address oldGame = baccaratGame;
        baccaratGame = _baccaratGame;
        emit BaccaratGameUpdated(oldGame, _baccaratGame);
    }

    /// @notice Requests random numbers for the initial card deal
    /// @dev Requests 4 random words for the initial 4 cards
    /// @return requestId The ID of the VRF request
    function requestRandomNumbers() external onlyBaccaratGame returns (uint256) {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash, subscriptionId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, INITIAL_NUM_WORDS
        );

        requestIdToFulfilled[requestId] = false;
        emit RandomNumberRequested(requestId);
        return requestId;
    }

    /// @notice Requests random numbers for additional cards
    /// @dev Requests 2 random words for potential third cards
    /// @return requestId The ID of the VRF request
    function requestAdditionalCards() external onlyBaccaratGame returns (uint256) {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash, subscriptionId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, ADDITIONAL_NUM_WORDS
        );

        requestIdToFulfilled[requestId] = false;
        emit RandomNumberRequested(requestId);
        return requestId;
    }

    /// @notice Callback function called by VRF Coordinator when random numbers are ready
    /// @dev Processes random numbers and forwards them to the Baccarat game contract
    /// @param requestId The ID of the VRF request being fulfilled
    /// @param randomWords Array of random numbers received from VRF
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        requestIdToFulfilled[requestId] = true;
        requestIdToRandomWords[requestId] = randomWords;
        emit RandomNumberFulfilled(requestId, randomWords);

        if (randomWords.length == INITIAL_NUM_WORDS) {
            // Initial deal
            uint8[4] memory cards;
            for (uint256 i = 0; i < 4; i++) {
                cards[i] = uint8((randomWords[i] % 52) + 1);
            }
            IBaccaratGame(baccaratGame).receiveInitialCards(requestId, cards);
        } else {
            // Additional cards
            uint8[2] memory cards;
            for (uint256 i = 0; i < 2; i++) {
                cards[i] = uint8((randomWords[i] % 52) + 1);
            }
            IBaccaratGame(baccaratGame).receiveThirdCard(requestId, cards);
        }
    }

    /// @notice Checks if a specific random number request has been fulfilled
    /// @param requestId The ID of the request to check
    /// @return bool True if the request has been fulfilled, false otherwise
    function isRequestFulfilled(uint256 requestId) external view returns (bool) {
        return requestIdToFulfilled[requestId];
    }

    /// @notice Retrieves the random numbers for a fulfilled request
    /// @param requestId The ID of the fulfilled request
    /// @return uint256[] Array of random numbers
    /// @dev Reverts if the request has not been fulfilled
    function getRandomNumbers(uint256 requestId) external view returns (uint256[] memory) {
        require(requestIdToFulfilled[requestId], "Request not fulfilled");
        return requestIdToRandomWords[requestId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/// @title BaccaratGame
/// @author [Your Name]
/// @notice A smart contract implementation of the Baccarat card game
/// @dev Implements standard Baccarat rules with betting, random card generation, and payout mechanics
contract BaccaratGame is ReentrancyGuard, Ownable, Pausable {
    // Enums
    enum BetType {
        PLAYER,
        BANKER,
        TIE
    }
    enum GameState {
        BETTING,
        DEALING,
        ENDED
    }

    // Structs
    /// @notice Represents a hand of cards in the game
    /// @dev Maximum of 3 cards per hand, stores both cards and computed value
    struct Hand {
        uint8[3] cards; // Max 3 cards per hand
        uint8 numCards; // Current number of cards in hand
        uint8 value; // Computed hand value (0-9)
    }

    /// @notice Represents a player's bet
    /// @dev Stores both the amount and type of bet
    struct Bet {
        uint256 amount; // Amount of ETH bet
        BetType betType; // Type of bet placed
    }

    /// @notice Stores the result of a completed game
    /// @dev Used for game history tracking
    struct GameResult {
        BetType winner; // Winning bet type
        uint8 playerScore; // Final player hand value
        uint8 bankerScore; // Final banker hand value
        uint256 timestamp; // When game ended
    }

    // State variables
    GameState public currentState;
    Hand public playerHand;
    Hand public bankerHand;
    mapping(address => Bet) public bets;
    address public oracleAddress;
    uint256 public currentRequestId;
    IRandomNumberGenerator public randomNumberGenerator;

    // Add these new state variables
    uint256 public constant MAX_HISTORY = 10;
    GameResult[] public gameHistory;
    mapping(BetType => uint256) public totalBetsByType;
    uint256 public bettingDeadline;
    uint256 public constant BETTING_PERIOD = 5 minutes;

    // Add a state variable to track accumulated commission
    uint256 private accumulatedCommission;

    // Events
    event GameStarted();
    event BetPlaced(address indexed player, uint256 amount, BetType betType);
    event CardDealt(string recipient, uint8 card);
    event GameEnded(BetType winner);
    event WinningsDistributed(address indexed winner, uint256 amount);
    event BettingOpened(uint256 deadline);
    event BettingClosed();
    event GameCancelled();
    event CommissionWithdrawn(uint256 amount);
    event ThirdCardDealt(BetType recipient, uint8 card);

    // Constants
    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant MAX_BET = 100 ether;
    uint256 public constant MIN_PLAYERS = 1;
    uint256 public constant MAX_TOTAL_BETS = 1000 ether;
    uint256 private constant SCALE = 10000; // For precise calculations

    // Add circular buffer for game history
    uint256 private historyIndex;

    /// @notice Initializes the Baccarat game contract
    /// @param _randomNumberGenerator Address of the random number generator contract
    constructor(address _randomNumberGenerator) Ownable(msg.sender) {
        randomNumberGenerator = IRandomNumberGenerator(_randomNumberGenerator);
        currentState = GameState.BETTING;
        bettingDeadline = block.timestamp + BETTING_PERIOD;
        emit BettingOpened(bettingDeadline);
    }

    /// @notice Allows a player to place a bet on the game outcome
    /// @param _betType The type of bet (PLAYER, BANKER, or TIE)
    /// @dev Requires minimum bet amount and checks various betting conditions
    /// @dev Emits BetPlaced event on success
    function placeBet(BetType _betType) external payable nonReentrant whenNotPaused {
        require(currentState == GameState.BETTING, "Not in betting phase");
        require(block.timestamp < bettingDeadline, "Betting period has ended");
        require(msg.value >= MIN_BET && msg.value <= MAX_BET, "Invalid bet amount");
        require(bets[msg.sender].amount == 0, "Bet already placed");

        uint256 newTotalBets = totalBetsByType[_betType] + msg.value;
        require(newTotalBets <= MAX_TOTAL_BETS, "Exceeds maximum total bets");

        // Update state before external interactions
        bets[msg.sender] = Bet({amount: msg.value, betType: _betType});
        playerRegistry[playerCount] = msg.sender;
        playerCount++;
        totalBetsByType[_betType] = newTotalBets;

        emit BetPlaced(msg.sender, msg.value, _betType);
    }

    /// @notice Starts the game after betting period ends
    /// @dev Can only be called by owner when enough bets are placed
    /// @dev Triggers the initial card dealing process
    function startGame() external onlyOwner whenNotPaused {
        require(currentState == GameState.BETTING, "Not in betting phase");
        require(playerCount >= MIN_PLAYERS, "Not enough players");
        require(address(this).balance > 0, "No bets placed");

        emit BettingClosed();
        currentState = GameState.DEALING;
        emit GameStarted();

        dealInitialCards();
    }

    function dealInitialCards() private {
        currentRequestId = randomNumberGenerator.requestRandomNumbers();
    }

    function receiveInitialCards(uint256 requestId, uint8[4] memory cards) external {
        require(msg.sender == address(randomNumberGenerator), "Only oracle can call");
        require(requestId == currentRequestId, "Invalid request ID");
        require(currentState == GameState.DEALING, "Not in dealing state");

        playerHand.cards[0] = cards[0];
        playerHand.cards[1] = cards[1];
        bankerHand.cards[0] = cards[2];
        bankerHand.cards[1] = cards[3];

        playerHand.numCards = 2;
        bankerHand.numCards = 2;

        calculateHandValue(playerHand);
        calculateHandValue(bankerHand);

        evaluateHands();
    }

    /// @notice Calculates the value of a hand according to Baccarat rules
    /// @param hand The hand to calculate value for
    function calculateHandValue(Hand storage hand) private {
        uint8 total = 0;
        for (uint8 i = 0; i < hand.numCards; i++) {
            uint8 cardValue = hand.cards[i] % 10; // Face cards (10, J, Q, K) are worth 0
            total += cardValue;
        }
        hand.value = total % 10; // Baccarat hand value is the last digit of the total
    }

    function evaluateHands() private {
        // Check if third card is needed
        if (needsThirdCard()) {
            requestThirdCard();
        } else {
            determineWinnerAndPayout();
        }
    }

    /// @notice Determines if a third card should be drawn according to Baccarat rules
    /// @return bool True if a third card should be drawn
    function needsThirdCard() public view returns (bool) {
        // If either hand has natural 8 or 9, no more cards
        if (playerHand.value >= 8 || bankerHand.value >= 8) {
            return false;
        }

        // Player draws first if total is 0-5
        if (playerHand.value <= 5) {
            return true;
        }

        // Banker draws according to rules if player stands
        if (playerHand.value >= 6 && bankerHand.value <= 5) {
            return true;
        }

        return false;
    }

    /// @notice Requests a third card from the random number generator
    /// @dev Updates currentRequestId with new request for additional cards
    function requestThirdCard() private {
        currentRequestId = randomNumberGenerator.requestAdditionalCards();
    }

    /// @notice Handles the receipt of third card(s) from the random number generator
    /// @param requestId The ID of the random number request to verify
    /// @param cards Array of up to 2 cards: [0] for player or banker's third card, [1] for banker's third card if player drew
    /// @dev Implements complex Baccarat rules for third card drawing
    /// @dev If player's value <= 5, draws third card for player and potentially banker
    /// @dev If player stands and banker's value <= 5, draws third card for banker only
    function receiveThirdCard(uint256 requestId, uint8[2] memory cards) external {
        require(msg.sender == address(randomNumberGenerator), "Only oracle can call");
        require(requestId == currentRequestId, "Invalid request ID");
        require(currentState == GameState.DEALING, "Not in dealing state");

        // Player draws first if needed
        if (playerHand.value <= 5) {
            playerHand.cards[2] = cards[0];
            playerHand.numCards = 3;
            calculateHandValue(playerHand);

            // Banker draws according to rules
            if (shouldBankerDraw(playerHand.cards[2])) {
                bankerHand.cards[2] = cards[1];
                bankerHand.numCards = 3;
                calculateHandValue(bankerHand);
            }
        } else if (bankerHand.value <= 5) {
            // Only banker draws
            bankerHand.cards[2] = cards[0];
            bankerHand.numCards = 3;
            calculateHandValue(bankerHand);
        }

        determineWinnerAndPayout();
    }

    /// @notice Determines if banker should draw based on player's third card
    /// @param playerThirdCard The value of player's third card
    /// @return bool True if banker should draw
    function shouldBankerDraw(uint8 playerThirdCard) public view returns (bool) {
        // Banker has natural - never draws
        if (bankerHand.value >= 7) return false;

        // Banker has very low hand - always draws
        if (bankerHand.value <= 2) return true;

        // Complex banker drawing rules based on banker's total and player's third card
        if (bankerHand.value == 3) {
            return playerThirdCard != 8;
        }
        if (bankerHand.value == 4) {
            return (playerThirdCard >= 2 && playerThirdCard <= 7);
        }
        if (bankerHand.value == 5) {
            return (playerThirdCard >= 4 && playerThirdCard <= 7);
        }
        if (bankerHand.value == 6) {
            return (playerThirdCard == 6 || playerThirdCard == 7);
        }

        return false;
    }

    /// @notice Determines the winner of the game and handles payouts
    /// @dev Compares hand values, updates game history, and triggers winnings distribution
    /// @dev Game history uses a circular buffer with MAX_HISTORY size
    /// @dev Emits GameEnded event with the winner
    function determineWinnerAndPayout() private {
        BetType winner;
        if (playerHand.value > bankerHand.value) {
            winner = BetType.PLAYER;
        } else if (bankerHand.value > playerHand.value) {
            winner = BetType.BANKER;
        } else {
            winner = BetType.TIE;
        }

        // Record game history
        if (gameHistory.length >= MAX_HISTORY) {
            // Remove oldest result
            for (uint256 i = 0; i < gameHistory.length - 1; i++) {
                gameHistory[i] = gameHistory[i + 1];
            }
            gameHistory.pop();
        }
        gameHistory.push(
            GameResult({
                winner: winner,
                playerScore: playerHand.value,
                bankerScore: bankerHand.value,
                timestamp: block.timestamp
            })
        );

        currentState = GameState.ENDED;
        distributeWinnings(winner);
        emit GameEnded(winner);
    }

    /// @notice Distributes winnings to players who bet on the winning outcome
    /// @dev Processes all winning bets in two phases:
    /// @dev 1. Calculate all winning amounts and clear bets
    /// @dev 2. Transfer winnings to winners
    /// @param winner The winning bet type (PLAYER, BANKER, or TIE)
    /// @dev Emits WinningsDistributed event for each winning payout
    /// @dev Throws "Insufficient contract balance" if contract can't cover payouts
    function distributeWinnings(BetType winner) private {
        address[] memory players = getPlayers();
        uint256[] memory winningAmounts = new uint256[](players.length);

        // Calculate winnings first
        for (uint256 i = 0; i < players.length; i++) {
            address player = players[i];
            Bet memory playerBet = bets[player];

            if (playerBet.betType == winner) {
                (uint256 winnings, uint256 commission) = calculateWinnings(playerBet.amount, winner);
                winningAmounts[i] = winnings;
                accumulatedCommission += commission; // Accumulate commission
            }
            // Clear bets before transfers
            delete bets[player];
        }

        // Perform transfers after all state changes
        for (uint256 i = 0; i < players.length; i++) {
            if (winningAmounts[i] > 0) {
                require(address(this).balance >= winningAmounts[i], "Insufficient contract balance");
                payable(players[i]).transfer(winningAmounts[i]);
                emit WinningsDistributed(players[i], winningAmounts[i]);
            }
        }
    }

    /// @notice Calculates winning amount and commission for a bet
    /// @param amount The bet amount in wei
    /// @param betType The type of bet placed
    /// @return winnings The amount won in wei
    /// @return commission The house commission in wei (only for banker bets)
    /// @dev Uses assembly for gas optimization
    function calculateWinnings(uint256 amount, BetType betType)
        private
        pure
        returns (uint256 winnings, uint256 commission)
    {
        assembly {
            switch betType
            case 1 {
                // BANKER
                // Calculate commission as 5% of the bet amount
                commission := div(mul(amount, 500), 10000)
                // Calculate winnings as 1.95 times the bet amount
                winnings := div(mul(amount, 19500), 10000)
            }
            case 0 {
                // PLAYER
                // Calculate winnings as 2 times the bet amount
                winnings := mul(amount, 2)
                commission := 0
            }
            default {
                // TIE
                // Calculate winnings as 9 times the bet amount
                winnings := mul(amount, 9)
                commission := 0
            }
        }
    }

    mapping(uint256 => address) private playerRegistry;
    uint256 private playerCount;

    /// @notice Gets all current players in the game
    /// @return Array of player addresses
    function getPlayers() private view returns (address[] memory) {
        address[] memory players = new address[](playerCount);
        for (uint256 i = 0; i < playerCount; i++) {
            players[i] = playerRegistry[i];
        }
        return players;
    }

    /// @notice Resets the game state for a new round
    /// @dev Can only be called by owner after game has ended or during cancellation
    /// @dev Clears all game state and opens new betting period
    function resetGame() internal {
        delete playerHand;
        delete bankerHand;
        playerCount = 0;
        currentState = GameState.BETTING;

        // Reset betting totals
        delete totalBetsByType[BetType.PLAYER];
        delete totalBetsByType[BetType.BANKER];
        delete totalBetsByType[BetType.TIE];

        // Set new betting deadline
        bettingDeadline = block.timestamp + BETTING_PERIOD;
        emit BettingOpened(bettingDeadline);
    }

    /// @notice Starts a new game round
    /// @dev Can only be called by owner after previous game has ended
    function startNewRound() external onlyOwner {
        require(currentState == GameState.ENDED, "Game not ended");
        resetGame();
    }

    /// @notice Cancels current game and refunds all bets
    /// @dev Only callable by owner during betting phase
    /// @dev Resets game state after refunding all bets
    function cancelGame() external onlyOwner {
        require(currentState == GameState.BETTING, "Can only cancel during betting");

        // Refund all bets
        address[] memory players = getPlayers();
        for (uint256 i = 0; i < players.length; i++) {
            address payable player = payable(players[i]);
            uint256 betAmount = bets[player].amount;
            if (betAmount > 0) {
                player.transfer(betAmount);
                delete bets[player];
            }
        }

        resetGame();
    }

    // Add these functions to BaccaratGame contract

    /// @notice Returns the current state of the game
    /// @return GameState The current game state (BETTING, DEALING, or ENDED)
    function getGameState() external view returns (GameState) {
        return currentState;
    }

    /// @notice Returns the current player and banker hands
    /// @dev Only accessible after cards have been dealt
    /// @return Hand Player's hand
    /// @return Hand Banker's hand
    function getCurrentHands() external view returns (Hand memory, Hand memory) {
        return (playerHand, bankerHand);
    }

    /// @notice Retrieves a player's current bet
    /// @param player The address of the player to check
    /// @return Bet The player's current bet information (amount and type)
    function getPlayerBet(address player) external view returns (Bet memory) {
        return bets[player];
    }

    /// @notice Returns the total number of players in the current game
    /// @return uint256 Number of players who have placed bets
    function getTotalPlayers() external view returns (uint256) {
        return playerCount;
    }

    /// @notice Returns the minimum and maximum allowed bet amounts
    /// @return uint256 Minimum bet amount in wei
    /// @return uint256 Maximum bet amount in wei
    function getBetLimits() external pure returns (uint256, uint256) {
        return (MIN_BET, MAX_BET);
    }

    /// @notice Checks if betting is currently open
    /// @return bool True if betting is open and deadline hasn't passed
    function isBettingOpen() public view returns (bool) {
        return currentState == GameState.BETTING && block.timestamp < bettingDeadline;
    }

    /// @notice Returns the remaining time for betting
    /// @return uint256 Time remaining in seconds, 0 if betting period has ended
    function getBettingTimeRemaining() public view returns (uint256) {
        if (block.timestamp >= bettingDeadline) return 0;
        return bettingDeadline - block.timestamp;
    }

    /// @notice Returns the complete game history
    /// @return GameResult[] Array of previous game results
    function getGameHistory() external view returns (GameResult[] memory) {
        return gameHistory;
    }

    /// @notice Returns the current total bets for each bet type
    /// @return uint256[3] Array of total bets [PLAYER, BANKER, TIE]
    function getCurrentBets() external view returns (uint256[3] memory) {
        return [totalBetsByType[BetType.PLAYER], totalBetsByType[BetType.BANKER], totalBetsByType[BetType.TIE]];
    }

    /// @notice Calculates potential winnings for a bet amount and type
    /// @param _betType The type of bet (PLAYER, BANKER, or TIE)
    /// @param _amount The bet amount in wei
    /// @return uint256 Potential winnings in wei, including original bet
    /// @dev Includes commission calculation for banker bets
    function calculatePotentialWinnings(BetType _betType, uint256 _amount) public pure returns (uint256) {
        uint256 potentialWinnings = _amount;

        if (_betType == BetType.BANKER) {
            uint256 commission = (_amount * 5) / 100;
            potentialWinnings = (_amount * 195) / 100 - commission;
        } else if (_betType == BetType.PLAYER) {
            potentialWinnings = _amount * 2;
        } else {
            // TIE
            potentialWinnings = _amount * 9;
        }

        return potentialWinnings;
    }

    /// @notice Pauses the contract in case of emergency
    /// @dev Only callable by contract owner
    function emergencyPause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract after emergency
    /// @dev Only callable by contract owner
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }

    /// @notice Allows owner to withdraw accumulated house commission
    /// @dev Only callable after game has ended
    /// @dev Transfers only the accumulated commission to owner
    function withdrawHouseCommission() external onlyOwner nonReentrant {
        require(currentState == GameState.ENDED, "Game not ended");
        require(accumulatedCommission > 0, "No commission to withdraw");

        uint256 commissionToWithdraw = accumulatedCommission;
        accumulatedCommission = 0; // Reset commission before transfer

        emit CommissionWithdrawn(commissionToWithdraw);
        payable(owner()).transfer(commissionToWithdraw);
    }

    /// @notice Returns the current balance of the contract
    /// @dev Only callable by contract owner
    /// @return uint256 Contract balance in wei
    function getContractBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /// @notice Starts a new game, resetting all game state
    /// @dev Only callable by owner when game has ended
    function startNewGame() external onlyOwner {
        require(currentState == GameState.ENDED, "Current game not ended");

        // Reset game state
        currentState = GameState.BETTING;
        bettingDeadline = block.timestamp + BETTING_PERIOD;

        // Reset hands
        delete playerHand;
        delete bankerHand;

        // Reset player count and registry
        playerCount = 0;

        // Reset total bets
        totalBetsByType[BetType.PLAYER] = 0;
        totalBetsByType[BetType.BANKER] = 0;
        totalBetsByType[BetType.TIE] = 0;

        emit BettingOpened(bettingDeadline);
    }
}

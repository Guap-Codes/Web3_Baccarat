## Baccarat Smart Contract Game

A decentralized implementation of the Baccarat card game on the Ethereum blockchain using Chainlink VRF for secure random number generation. Built with Foundry.

## Overview

This project implements a fully decentralized version of Baccarat, consisting of:
- `BaccaratGame.sol`: Main game contract handling betting, game logic, and payouts
- `RandomNumberGenerator.sol`: Random number generation contract using Chainlink VRF

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- [Chainlink VRF Subscription](https://vrf.chain.link/)
- An Ethereum wallet with testnet/mainnet ETH
- Basic knowledge of Ethereum and smart contracts

## Installation

1. Clone the repository:

```shell
git clone <repository-url>
cd baccarat-smart-contract
```

2. Install dependencies:

```shell
forge install
```

3. Build the project:

```shell
forge build
```

## Deployment

1. Create a `.env` file:

```env
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
CHAINLINK_VRF_COORDINATOR=coordinator_address
CHAINLINK_SUBSCRIPTION_ID=subscription_id
CHAINLINK_KEY_HASH=key_hash
```

2. Deploy the contracts:

```shell
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast --verify
```

## Interacting with the Game

### Using the Foundry Cast Command

#### For Players

1. Place a bet:

```bash
# Bet on PLAYER (0)
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "placeBet(uint8)" 0 --value 0.1ether

# Bet on BANKER (1)
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "placeBet(uint8)" 1 --value 0.1ether

# Bet on TIE (2)
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "placeBet(uint8)" 2 --value 0.1ether
```

2. Check your bet:

```bash
cast call $BACCARAT_ADDRESS "getPlayerBet(address)" $YOUR_ADDRESS
```

3. View game state:

```bash
cast call $BACCARAT_ADDRESS "getGameState()" 
```

4. View current hands after dealing:

```bash
cast call $BACCARAT_ADDRESS "getCurrentHands()"
```

#### For Contract Owner (Banker)

1. Start the game:

```bash
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "startGame()"
```

2. Reset game for new round:

```bash
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "resetGame()"
```

3. Withdraw commission:

```bash
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "withdrawHouseCommission()"
```

4. Emergency controls:

```bash
# Pause
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "emergencyPause()"

# Unpause
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $BACCARAT_ADDRESS "emergencyUnpause()"
```

### Using Foundry Scripts

The project includes custom scripts for both Players and Bankers (contract owners) in the `script` directory:

#### Player Scripts (PlayerActions.s.sol)

Execute player actions using the following commands:

```bash
# Place bet on Player
forge script script/PlayerActions.s.sol:PlayerActions --sig "placeBetOnPlayer()" --rpc-url $RPC_URL --broadcast

# Place bet on Banker
forge script script/PlayerActions.s.sol:PlayerActions --sig "placeBetOnBanker()" --rpc-url $RPC_URL --broadcast

# Place bet on Tie
forge script script/PlayerActions.s.sol:PlayerActions --sig "placeBetOnTie()" --rpc-url $RPC_URL --broadcast

# Check your current bet
forge script script/PlayerActions.s.sol:PlayerActions --sig "checkMyBet()" --rpc-url $RPC_URL

# View current game state
forge script script/PlayerActions.s.sol:PlayerActions --sig "checkGameState()" --rpc-url $RPC_URL

# View current hands
forge script script/PlayerActions.s.sol:PlayerActions --sig "viewCurrentHands()" --rpc-url $RPC_URL
```

#### Banker Scripts (BankerActions.s.sol)

Execute banker (owner) actions using the following commands:

```bash
# Start a new game
forge script script/BankerActions.s.sol:BankerActions --sig "startNewGame()" --rpc-url $RPC_URL --broadcast

# Reset the game round
forge script script/BankerActions.s.sol:BankerActions --sig "resetGameRound()" --rpc-url $RPC_URL --broadcast

# Withdraw house commission
forge script script/BankerActions.s.sol:BankerActions --sig "withdrawCommission()" --rpc-url $RPC_URL --broadcast

# Emergency pause
forge script script/BankerActions.s.sol:BankerActions --sig "pauseGame()" --rpc-url $RPC_URL --broadcast

# Emergency unpause
forge script script/BankerActions.s.sol:BankerActions --sig "unpauseGame()" --rpc-url $RPC_URL --broadcast

# Check total bets
forge script script/BankerActions.s.sol:BankerActions --sig "checkTotalBets()" --rpc-url $RPC_URL
```

Note: Before running these scripts:
1. Ensure your `.env` file is properly configured with your private key and RPC URL
2. For Banker actions, make sure you're using the contract owner's private key
3. Replace `BACCARAT_ADDRESS` in the scripts with your deployed contract address

## Game Rules and Mechanics

### Betting Limits
- Minimum bet: 0.01 ETH
- Maximum bet: 100 ETH
- Maximum total bets: 1000 ETH per type
- Betting period: 5 minutes

### Payouts
- Player bet: 2:1
- Banker bet: 1.95:1 (5% commission)
- Tie bet: 9:1

### Game Flow
1. Betting phase opens
2. Players place bets
3. Betting phase closes
4. Initial cards are dealt
5. Third card rules are applied if necessary
6. Winner is determined
7. Winnings are distributed
8. Game resets for next round

## Testing

Run the test suite:

```bash
forge test
```

Run tests with verbosity:

```bash
forge test -vv
```

Run specific tests:

```bash
forge test --match-test testPlaceBet
```

## Gas Reports

Generate gas reports:

```bash
forge test --gas-report
```

## Contract Verification

Verify contracts on Etherscan:

```bash
forge verify-contract $BACCARAT_ADDRESS src/BaccaratGame.sol:BaccaratGame --chain-id 1 --compiler-version v0.8.4
```

## Security Considerations

- Uses OpenZeppelin's security contracts
- Implements ReentrancyGuard
- Includes emergency pause functionality
- Secure random number generation via Chainlink VRF
- Regular security audits recommended

## License

This project is licensed under the MIT License.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## Support

For support and queries:
1. Open an issue in the repository
2. Check existing documentation
3. Review test files for examples
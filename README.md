
# Auction Smart Contract

This project implements a simple on-chain auction system using Clarity smart contracts. It allows users to create auctions, place bids, and finalize auctions. The smart contract includes logic for bid validation, auction duration, and ownership controls.

## Features

1. **Start Auction**: Allows a user to start an auction with a specified duration.
2. **Place Bid**: Allows participants to place bids higher than the current highest bid.
3. **End Auction**: The auction owner can end the auction and declare the winner once the auction duration has passed.

## Smart Contract Functions

### `start-auction (duration uint)`
- **Description**: Starts a new auction with the given duration.
- **Parameters**:
  - `duration`: The number of blocks for which the auction will run.
- **Returns**: `"Auction started"` on success or an error if the auction is already started.

### `place-bid (amount uint)`
- **Description**: Places a bid in the auction if the bid is higher than the current highest bid.
- **Parameters**:
  - `amount`: The bid amount.
- **Returns**: `"Bid placed"` on success or an error if the bid is too low or the auction has ended.

### `end-auction`
- **Description**: Ends the auction and declares the highest bidder.
- **Returns**: The principal of the highest bidder on success or an error if the auction is still ongoing or the caller is not the auction owner.

## Unit Tests

Unit tests for the auction contract are written using `Vitest`. They simulate the contract logic and validate various scenarios.

### Test Cases

1. **Start Auction**:
   - Verifies that a user can start an auction with a valid duration.
   - Ensures that no other auction can be started until the current one ends.

2. **Place Bid**:
   - Validates that bids higher than the current highest bid are accepted.
   - Ensures that bids lower than or equal to the current highest bid are rejected.
   - Prevents bidding after the auction ends.

3. **End Auction**:
   - Allows the auction owner to end the auction after it has concluded.
   - Prevents non-owners from ending the auction.
   - Ensures the auction cannot be ended while it is still ongoing.

## GitHub Workflow

The project includes a GitHub Actions workflow to automatically run unit tests on push events.

### Workflow File

```yaml
name: Run Unit Tests

on:
  push:
    branches:
      - main
      - feature/*

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '16'

    - name: Install dependencies
      run: npm install

    - name: Run Unit Tests
      run: npm test
```

## Installation and Usage

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. **Install Dependencies**:
   ```bash
   npm install
   ```

3. **Run Tests**:
   ```bash
   npm test
   ```

## License

This project is licensed under the MIT License.

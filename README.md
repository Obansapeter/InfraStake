# 🏗️ InfraStake — Infrastructure Staking Smart Contract

**InfraStake** is a secure and efficient smart contract designed to facilitate staking of ERC20 tokens towards infrastructure projects. It enables users to stake tokens, earn rewards based on their stake and duration, and withdraw their funds safely, supporting decentralized participation in infrastructure development.

---

## 🚀 Features

- 💰 **Token Staking**
  - Users stake supported ERC20 tokens into the infrastructure pool.
  - Stake balances tracked per user with real-time updates.

- 🎁 **Rewards Mechanism**
  - Rewards accrue proportionally to staked amount and time.
  - Supports reward claiming without affecting stake principal.

- 🔄 **Flexible Withdrawals**
  - Partial or full withdrawal of staked tokens allowed anytime.
  - Updates staking and rewards balances accordingly.

- 🛡️ **Security & Control**
  - Reentrancy guard protects critical functions.
  - Emergency pause/unpause by authorized roles.
  - Input validation to prevent invalid operations.

---

## 🧱 Architecture

### Key Components

- **Staking Functions**

```solidity
function stake(uint256 amount) external;
function withdraw(uint256 amount) external;
function claimRewards() external;
Administrative Functions

solidity
function pause() external onlyOwner;
function unpause() external onlyOwner;
Reward Calculation
Rewards are calculated based on a per-block or per-second rate, proportionally distributed relative to user stakes and total pool size. The contract maintains snapshots of stake and reward variables to ensure accuracy.

📦 Installation
Clone the repo and install dependencies:

bash
git clone https://github.com/yourusername/InfraStake.git
cd InfraStake
npm install
🚀 Deployment
Compile and deploy with Hardhat:

bash
npx hardhat compile
npx hardhat run scripts/deploy.js --network <network-name>
Configure environment variables for your network RPC URL and private keys.

🔍 Usage Example
Staking Tokens
js
await infraStake.stake(ethers.utils.parseUnits("100.0", 18));
Claiming Rewards
js
await infraStake.claimRewards();
Withdrawing Stake
js
await infraStake.withdraw(ethers.utils.parseUnits("50.0", 18));
✅ Testing
Run the test suite with:

bash

npx hardhat test
Tests cover:

Staking workflows

Rewards accumulation and claiming

Withdrawals and balance updates

Pause/unpause functionality and access control

🔐 Security Considerations
Uses OpenZeppelin’s ReentrancyGuard to prevent reentrancy attacks.

Validates staking and withdrawal amounts to prevent underflow/overflow.

Emergency pause implemented for quick response to incidents.

Thoroughly tested for edge cases and attack vectors.

📁 Project Structure
bash
contracts/
├── InfraStake.sol           # Main staking contract

scripts/
├── deploy.js                # Deployment script

test/
├── infraStake.test.js       # Comprehensive tests

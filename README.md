# 🌍 Bitcoin-Backed Universal Basic Income (UBI)

A decentralized Universal Basic Income system built on Stacks blockchain that distributes STX tokens based on participation, staking, and verified need.

## 🚀 Features

- **🔐 Participant Registration**: Users can register to become eligible for UBI distributions
- **💰 Token Staking**: Stake STX tokens to increase UBI rewards through multipliers
- **✅ Identity Verification**: Verification system to ensure legitimate participants
- **🎯 Smart Distribution**: UBI amounts calculated based on verification score, participation, and staking
- **⏰ Round-based Claims**: Periodic distribution rounds prevent double-claiming
- **🏊 Community Pool**: Anyone can contribute to the UBI distribution pool

## 📋 How It Works

### For Participants

1. **Register** as a participant in the system
2. **Stake tokens** (optional) to increase your UBI multiplier
3. **Request verification** to improve your eligibility score
4. **Claim UBI** each distribution round based on your calculated amount

### For Contributors

1. **Contribute to pool** by sending STX tokens to fund UBI distributions
2. **Verify participants** (if authorized) to help maintain system integrity

## 🛠 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `register-participant` | Register as a UBI participant |
| `stake-tokens` | Stake STX tokens for reward multipliers |
| `request-verification` | Request identity verification |
| `claim-ubi` | Claim your UBI for the current round |
| `contribute-to-pool` | Add funds to the UBI distribution pool |
| `withdraw-stake` | Withdraw your staked tokens |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-participant-info` | Get participant details and stats |
| `get-pool-balance` | Check current pool balance |
| `calculate-ubi-amount` | Calculate UBI amount for a participant |
| `is-eligible-for-claim` | Check if participant can claim UBI |

## 💡 UBI Calculation

Your UBI amount is calculated using:

```
Base Amount × (Verification Score + Participation Score + Stake Multiplier)
```

### Stake Multipliers
- **1x**: Minimum stake (1 STX)
- **2x**: 5× minimum stake
- **3x**: 10× minimum stake

## 🎮 Usage Examples

### Register and Stake
```clarity
;; Register as participant
(contract-call? .bitcoin-backed-universal register-participant)

;; Stake 5 STX tokens
(contract-call? .bitcoin-backed-universal stake-tokens u5000000)
```

### Claim UBI
```clarity
;; Check eligibility
(contract-call? .bitcoin-backed-universal is-eligible-for-claim tx-sender)

;; Claim your UBI
(contract-call? .bitcoin-backed-universal claim-ubi)
```

### Contribute to Pool
```clarity
;; Add 10 STX to the UBI pool
(contract-call? .bitcoin-backed-universal contribute-to-pool u10000000)
```

## 🔧 Development

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Testing
```bash
clarinet test
```

### Deploy
```bash
clarinet deploy
```

## 🌟 Social Impact

This UBI system aims to:
- **Reduce inequality** through fair token distribution
- **Incentivize participation** in the Stacks ecosystem
- **Support those in need** through verified assistance
- **Build community** through collaborative funding

## ⚠️ Important Notes

- Contract owner has administrative privileges for verification and round management
- Participants can only claim once per round
- Staked tokens can be withdrawn at any time
- Pool must have sufficient balance for claims to succeed

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for improvements.

---

*Built with ❤️ for social impact on Stacks blockchain*
```

**Git Commit Message:**
```
feat: implement Bitcoin-backed UBI system with staking and verification
```

**GitHub Pull Request Title:**
```
🌍 Add Bitcoin-Backed Universal Basic Income Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## Summary
This PR introduces a complete MVP for a Bitcoin-Backed Universal Basic Income (UBI) system built on Stacks blockchain.

## What's Added
- **Core UBI Contract**: Complete Clarity smart contract with participant registration, staking, verification, and claim mechanisms
- **Staking System**: Token staking with reward multipliers (1x, 2x, 3x based on stake amount)
- **Verification System**: Identity verification to ensure legitimate participants
- **Round-based Distribution**: Prevents double-claiming with periodic distribution rounds
- **Community Pool**: Allows anyone to contribute funds for UBI distribution
- **Comprehensive Documentation**: Detailed README with usage examples and feature explanations

## Key Features
✅ Participant registration and management  
✅ STX token staking with multipliers  
✅ Identity verification system  
✅ Smart UBI calculation based on multiple factors  
✅ Round-based claim prevention  
✅ Community-funded distribution pool  
✅ Administrative controls for system


# Hardhat Payment Gateway

A Solidity-based payment gateway contract for secure, flexible, and tax-compliant payments using native tokens or ERC20 tokens. Built with Hardhat and OpenZeppelin, this project enables merchants to accept payments, manage transactions, and handle refunds with built-in tax logic.

## Features

- **Supports Native & ERC20 Token Payments:** Accept payments in ETH or any allowed ERC20 token.
- **Tax Deduction:** Automatically deducts a configurable tax (default: 0.5%) and sends it to a specified tax address.
- **Transaction Management:** Create, pay, and refund transactions with full event logging.
- **Shop Owner & Payer Tracking:** Query transactions by payer or shop owner.
- **Reentrancy Protection:** Secure against reentrancy attacks.
- **Owner Controls:** Add/remove allowed tokens, update tax address, emergency withdrawal.

## Contract: `PaymentGatewayDirect`

See [`contracts/paymentGateway.sol`](contracts/paymentGateway.sol) for full implementation.

### Key Functions

- `createTransaction(originChain, totalPayment, shopOwner, paymentToken)`
- `payTransaction(transactionId)` (native token)
- `payTransactionWithToken(transactionId)` (ERC20)
- `refundTransaction(transactionId)`
- `getTransaction(transactionId)`
- `getPayerTransactions(payer)`
- `getShopOwnerTransactions(shopOwner)`
- `addAllowedToken(token)`
- `removeAllowedToken(token)`
- `updateTaxAddress(newTaxAddress)`
- `emergencyWithdraw()`

## Getting Started

### Prerequisites

- Node.js & npm
- Hardhat (`npm install --save-dev hardhat`)
- OpenZeppelin Contracts (`npm install @openzeppelin/contracts`)

### Installation

```bash
git clone <your-repo-url>
cd hardhat_payment_gateway
npm install
```

## Usage

### Compile Contracts

```bash
npx hardhat compile
```

### Deploy Contract

Edit deployment parameters in `scripts/deploy.js` or use Hardhat Ignition:

```bash
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

### Run Local Node

```bash
npx hardhat node
```

### Run Tests

```bash
npx hardhat test
REPORT_GAS=true npx hardhat test
```

### Manual Transaction Test

```bash
node scripts/testCreateTransaction.js
```

## Example: Creating & Paying a Transaction

1. **Create Transaction**
	- Call `createTransaction` with shop owner, payment amount, origin chain, and token address.

2. **Pay Transaction**
	- For native token: call `payTransaction(transactionId)` and send ETH.
	- For ERC20: call `payTransactionWithToken(transactionId)` after approving the contract.

3. **Refund Transaction**
	- Shop owner calls `refundTransaction(transactionId)` to refund the payer.

## Events

- `TransactionCreated`
- `TransactionPaid`
- `TransactionRefunded`
- `TaxAddressUpdated`
- `TokenAllowed`
- `TokenRemoved`

## Security

- Uses OpenZeppelin's `Ownable` and `SafeERC20`.
- Reentrancy protection via `nonReentrant` modifier.
- Rejects direct payments and unknown function calls.

## License

MIT

---

For more details, see the contract source and scripts in this repository.
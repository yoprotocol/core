# YO Protocol

![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

## Overview

Yo Protocol provides a modular, ERC4626-compliant vault designed for cross-chain asset management and optimized
liquidity operations. The vault enables users to deposit assets while providing operators with controlled management
capabilities, including asset transfers, redemptions, and fee handling. The contract architecture allows seamless
integration with external strategies, oracles, and cross-chain liquidity mechanisms.

## Key Features

- **ERC4626 Compatibility**: Implements the ERC4626 vault standard for tokenized vaults.
- **Asynchronous Redemption**: Users can request asset redemptions, which are fulfilled by an operator.
- **Cross-Chain Liquidity Management**: Supports integrations with external liquidity sources and strategies.
- **Fee Mechanism**: Configurable deposit and withdrawal fees, with a designated fee recipient.
- **Access Control**: Role-based authorization via an upgradable `AuthUpgradeable` contract.
- **Oracle Integration**: Fetches and updates underlying balances from an oracle.
- **Pausability**: The contract can be paused in case of unexpected market events.

## Contracts Structure

### Core Contracts

- **[`yoVault.sol`](https://github.com/yoprotocol/core/blob/main/src/yoVault.sol)**: Implements the main vault
  functionality, including deposits, redemptions, and balance tracking.
- **[`Escrow.sol`](https://github.com/yoprotocol/core/blob/main/src/Escrow.sol)**: An escrow contract for controlled
  asset withdrawals.
- **[`Compatible.sol`](https://github.com/yoprotocol/core/blob/main/src/Compatible.sol)**: Allows the contract to
  receive ETH and ERC721/ERC1155 tokens.
- **[`AuthUpgradeable.sol`](https://github.com/yoprotocol/core/blob/main/src/AuthUpgradable.sol)**: Upgradable access
  control contract.

### Libraries

- **[`Errors.sol`](https://github.com/yoprotocol/core/blob/main/src/libraries/Errors.sol)**: Defines error messages for
  consistent and gas-efficient error handling.
- **OpenZeppelin Libraries**: Uses `SafeERC20`, `Math`, `PausableUpgradeable`, and other battle-tested utilities.

## Deployment

### yoVault Deployments

#### yoETH

| Network  | Contract Address                           |
| -------- | ------------------------------------------ |
| Base     | 0x3a43aec53490cb9fa922847385d82fe25d0e9de7 |
| Ethereum | 0x3a43aec53490cb9fa922847385d82fe25d0e9de7 |

### Authority Deployments

| Network  | Contract Address                           |
| -------- | ------------------------------------------ |
| Base     | 0x9524e25079b1b04D904865704783A5aA0202d44D |
| Ethereum | 0x9524e25079b1b04D904865704783A5aA0202d44D |

## Installation & Setup

Ensure you have [Foundry](https://book.getfoundry.sh/) installed. Then, clone the repository and install dependencies:

```sh
$ git clone https://github.com/your-org/yoVault.git
$ cd yoVault
$ bun install
```

## Usage

### Compilation

```sh
$ forge build
```

### Testing

```sh
$ forge test
```

## Security Considerations

- **Upgradeable Design**: The contract is upgradeable via OpenZeppelin proxies.
- **Restricted Access**: Functions requiring privileged access are protected via `AuthUpgradeable`.
- **Oracle-Based Pausing**: The contract automatically pauses if detected balance discrepancies exceed a configured
  threshold.

## License

This project is licensed under the [MIT License](https://chatgpt.com/c/LICENSE).

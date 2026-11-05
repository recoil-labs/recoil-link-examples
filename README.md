# Recoil Link examples

Runnable examples for [Recoil Link](https://github.com/recoil-labs/recoil-link): cross-chain messaging with proof. A contract on one chain sends a message; Recoil Link's validators attest to it and its relayer delivers it, so a contract on another chain can act on it and trust where it came from.

Every example has Foundry tests that run locally on two mock Mailboxes, and a script that deploys and runs it on public testnets.

| Example | What it shows | Contracts |
| --- | --- | --- |
| [Hello](src/hello) | The minimum: send text to a contract on another chain, pay the fee, receive it | `HelloSender`, `HelloReceiver` |
| [Governance](src/governance) | A governor on one chain makes calls on another, and only that governor can | `CrossChainGovernor`, `GovernedExecutor` |
| [Deposits](src/deposits) | Prove an event (a deposit) on one chain so a contract on another can act on it | `DepositVault`, `DepositRegistry` |
| [TypeScript SDK](sdk/send-and-wait.mjs) | Send a message and wait for delivery from a script | `@recoillink/sdk` |

Recoil Link is on **testnet**, secured by one validator. Don't move real value with it yet.

## Setup

You need [Node.js 22+](https://nodejs.org), [Foundry](https://book.getfoundry.sh/getting-started/installation) and `jq`.

```bash
npm install
forge test
```

All Solidity dependencies come from the [`@recoillink/core`](https://www.npmjs.com/package/@recoillink/core) npm package, which bundles the OpenZeppelin and forge-std versions it was built with. `remappings.txt` points at them; copy it into your own project.

## Run on testnets

Each script deploys the example's contracts, sends one message from Base Sepolia to OP Sepolia, and waits for delivery (usually under a minute).

```bash
export PRIVATE_KEY=0x...   # a throwaway testnet key, never one that holds real funds
scripts/hello.sh
scripts/governance.sh
scripts/deposits.sh
```

The key needs a little test ETH on both chains: on the default route all three scripts together spend well under 0.001 ETH, most of it the 0.0001 ETH the Deposits example deposits. Other routes: pass the origin and destination, for example `scripts/hello.sh sepolia basesepolia`. Supported: `sepolia`, `basesepolia`, `optimismsepolia`, `bsctestnet`.

For the TypeScript example, which sends from Sepolia to Base Sepolia's built-in test recipient:

```bash
HYP_KEY=$PRIVATE_KEY node sdk/send-and-wait.mjs
```

## How the examples stay safe

A receiving contract's `handle` is called by its chain's Mailbox. Each example checks, in this order:

1. **`msg.sender == mailbox`**: only the Mailbox delivers; anyone else calling `handle` could fake a message.
2. **The origin chain and sender** (Governance and Deposits): a message counts only if it came from the one contract you trust, on the one chain you expect. The tests show a look-alike contract and a different chain both being rejected.

Senders pay exactly the quoted fee and refund the rest to the caller. Overpaying the Mailbox would refund the sending contract instead.

## Learn more

- [Recoil Link docs](https://docs.link.recoilpay.com): quickstart, send and receive messages, gas and fees, message debugging
- [Recoil Link registry](https://github.com/recoil-labs/recoil-link-registry): chain metadata and contract addresses

## License

MIT

// Sends a message from Sepolia to Base Sepolia's test recipient with the
// TypeScript SDK, then waits until the relayer has delivered it.
//   HYP_KEY=0x... node sdk/send-and-wait.mjs

import { Wallet } from 'ethers';
import { HyperlaneCore, MultiProvider } from '@recoillink/sdk';
import { ProtocolType } from '@recoillink/utils';

const multiProvider = new MultiProvider({
  sepolia: {
    name: 'sepolia',
    chainId: 11155111,
    domainId: 11155111,
    protocol: ProtocolType.Ethereum,
    rpcUrls: [{ http: 'https://ethereum-sepolia.publicnode.com' }],
  },
  basesepolia: {
    name: 'basesepolia',
    chainId: 84532,
    domainId: 84532,
    protocol: ProtocolType.Ethereum,
    rpcUrls: [{ http: 'https://sepolia.base.org' }],
  },
});
multiProvider.setSharedSigner(new Wallet(process.env.HYP_KEY));

const core = HyperlaneCore.fromAddressesMap(
  {
    sepolia: { mailbox: '0xA066332EF9C28158BDCf45D1a6138219e86CB6c6' },
    basesepolia: { mailbox: '0x078fba178e69c61cce09Fd7f1AE2f413B6c65c20' },
  },
  multiProvider,
);

// Base Sepolia's test recipient: accepts any message.
const recipient = '0xb0CaE038F60Bb9eb5A127A062E908497d50c4bD9';
const body = '0x' + Buffer.from('hello from Sepolia').toString('hex');

// sendMessage quotes the fee and pays it.
const { dispatchTx, message } = await core.sendMessage(
  'sepolia',
  'basesepolia',
  recipient,
  body,
);
console.log('message id:', message.id);

// Poll the destination Mailbox until the relayer has delivered it.
await core.waitForMessageProcessed(dispatchTx, 5_000, 60);
console.log('delivered on Base Sepolia');

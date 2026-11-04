#!/usr/bin/env bash
# Deploys a DepositVault on the origin and a DepositRegistry that trusts it on
# the destination, deposits a little test ETH, and waits for the proof.
#   PRIVATE_KEY=0x... scripts/deposits.sh [origin] [destination]
cd "$(dirname "$0")/.."
source scripts/lib.sh
load O "${1:-basesepolia}"
load D "${2:-optimismsepolia}"

deploy vault O src/deposits/DepositVault.sol:DepositVault "$O_MAILBOX"
echo "DepositVault on ${1:-basesepolia}: $vault"
deploy registry D src/deposits/DepositRegistry.sol:DepositRegistry "$D_MAILBOX" "$O_DOMAIN" "$vault"
echo "DepositRegistry on ${2:-optimismsepolia}: $registry"

amount=$(cast to-wei 0.0001)
fee=$(read_call "$O_RPC" "$vault" 'quote(uint32,address,uint256)(uint256)' "$D_DOMAIN" "$registry" "$amount")
send O "$(( amount + fee ))" "$vault" 'deposit(uint32,address,uint256)' "$D_DOMAIN" "$registry" "$amount"
echo "Deposited 0.0001 ETH in $TX (message fee $fee wei)"

wait_for "the deposit proof" "$amount" "$D_RPC" "$registry" 'creditOf(address)(uint256)' "$ME"
echo "Registry on ${2:-optimismsepolia} credits $ME with $amount wei."

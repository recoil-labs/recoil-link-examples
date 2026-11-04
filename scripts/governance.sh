#!/usr/bin/env bash
# Deploys a CrossChainGovernor (owned by you) on the origin, and a
# GovernedExecutor plus an ExampleSettings it owns on the destination. Then the
# governor changes the setting across chains.
#   PRIVATE_KEY=0x... scripts/governance.sh [origin] [destination]
cd "$(dirname "$0")/.."
source scripts/lib.sh
load O "${1:-basesepolia}"
load D "${2:-optimismsepolia}"

deploy governor O src/governance/CrossChainGovernor.sol:CrossChainGovernor "$O_MAILBOX" "$ME"
echo "CrossChainGovernor on ${1:-basesepolia}: $governor"
deploy executor D src/governance/GovernedExecutor.sol:GovernedExecutor "$D_MAILBOX" "$O_DOMAIN" "$governor"
echo "GovernedExecutor on ${2:-optimismsepolia}: $executor"
deploy settings D src/governance/ExampleSettings.sol:ExampleSettings "$executor"
echo "ExampleSettings on ${2:-optimismsepolia}: $settings (feeBps = $(read_call "$D_RPC" "$settings" 'feeBps()(uint256)'))"

calls="[($settings,0,$(cast calldata 'setFeeBps(uint256)' 25))]"
fee=$(read_call "$O_RPC" "$governor" 'quote(uint32,address,(address,uint256,bytes)[])(uint256)' "$D_DOMAIN" "$executor" "$calls")
send O "$fee" "$governor" 'execute(uint32,address,(address,uint256,bytes)[])' "$D_DOMAIN" "$executor" "$calls"
echo "Proposal sent in $TX: set feeBps to 25"

wait_for "the proposal" 25 "$D_RPC" "$settings" 'feeBps()(uint256)'
echo "feeBps on ${2:-optimismsepolia} is now 25."

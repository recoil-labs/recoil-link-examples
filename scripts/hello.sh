#!/usr/bin/env bash
# Deploys HelloReceiver on the destination and HelloSender on the origin,
# sends one message and waits for it to arrive.
#   PRIVATE_KEY=0x... scripts/hello.sh [origin] [destination]
cd "$(dirname "$0")/.."
source scripts/lib.sh
load O "${1:-basesepolia}"
load D "${2:-optimismsepolia}"

deploy receiver D src/hello/HelloReceiver.sol:HelloReceiver "$D_MAILBOX"
echo "HelloReceiver on ${2:-optimismsepolia}: $receiver"
deploy sender O src/hello/HelloSender.sol:HelloSender "$O_MAILBOX"
echo "HelloSender on ${1:-basesepolia}: $sender"

text="hello from ${1:-basesepolia}"
fee=$(read_call "$O_RPC" "$sender" 'quote(uint32,address,string)(uint256)' "$D_DOMAIN" "$receiver" "$text")
echo "Fee: $fee wei"
send O "$fee" "$sender" 'sendHello(uint32,address,string)' "$D_DOMAIN" "$receiver" "$text"
echo "Sent in $TX"

wait_for "the message" 1 "$D_RPC" "$receiver" 'received()(uint256)'
echo "Receiver says: $(cast call --rpc-url "$D_RPC" "$receiver" 'lastText()(string)')"

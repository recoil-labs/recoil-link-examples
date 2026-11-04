# Shared helpers for the testnet scripts. Sourced, not run.
# Needs: foundry (forge, cast), jq, and PRIVATE_KEY set to a testnet key.
set -euo pipefail

: "${PRIVATE_KEY:?Set PRIVATE_KEY to a testnet-only key with a little test ETH on both chains}"

# load <prefix> <chain>: sets <prefix>_RPC, <prefix>_DOMAIN, <prefix>_MAILBOX.
# Addresses: https://github.com/recoil-labs/recoil-link-registry
load() {
  local rpc domain mailbox
  case "$2" in
    sepolia)         rpc=https://ethereum-sepolia.publicnode.com; domain=11155111; mailbox=0xA066332EF9C28158BDCf45D1a6138219e86CB6c6 ;;
    basesepolia)     rpc=https://sepolia.base.org;                domain=84532;    mailbox=0x078fba178e69c61cce09Fd7f1AE2f413B6c65c20 ;;
    optimismsepolia) rpc=https://sepolia.optimism.io;             domain=11155420; mailbox=0x0B10f22CDF275293f7B4a995699440B04799c3bC ;;
    bsctestnet)      rpc=https://bsc-testnet.publicnode.com;      domain=97;       mailbox=0x7f3450D5f8Dc984ba38e3Cb8DAD31e2a3Ecd8893 ;;
    *) echo "Unknown chain '$2'. Use sepolia, basesepolia, optimismsepolia or bsctestnet." >&2; exit 1 ;;
  esac
  printf -v "$1_RPC" '%s' "$rpc"
  printf -v "$1_DOMAIN" '%s' "$domain"
  printf -v "$1_MAILBOX" '%s' "$mailbox"
}

ME=$(cast wallet address --private-key "$PRIVATE_KEY")

# Nonces are counted here, not re-read from the RPC before every transaction:
# public RPCs are load-balanced and can report a stale nonce right after a send.
take_nonce() {
  local var="$1_NONCE" rpc="$1_RPC"
  if [ -z "${!var:-}" ]; then
    printf -v "$var" '%s' "$(cast nonce --rpc-url "${!rpc}" "$ME")"
  fi
  NONCE=${!var}
  printf -v "$var" '%s' $(( NONCE + 1 ))
}

# deploy <var> <prefix> <path:Contract> [constructor args...]: deploys on that
# chain and sets <var> to the new address.
deploy() {
  local out=$1 p=$2 contract=$3; shift 3
  local rpc="${p}_RPC"
  take_nonce "$p"
  local addr
  addr=$(forge create --rpc-url "${!rpc}" --private-key "$PRIVATE_KEY" --nonce "$NONCE" --broadcast \
    "$contract" --constructor-args "$@" | awk '/Deployed to:/ {print $3}')
  [ -n "$addr" ] || { echo "Deploying $contract failed." >&2; exit 1; }
  printf -v "$out" '%s' "$addr"
}

# send <prefix> <value> <address> <signature> [args...]: sends a transaction
# on that chain and sets TX to its hash.
send() {
  local p=$1 value=$2 to=$3; shift 3
  local rpc="${p}_RPC"
  take_nonce "$p"
  TX=$(cast send --rpc-url "${!rpc}" --private-key "$PRIVATE_KEY" --nonce "$NONCE" --value "$value" --json \
    "$to" "$@" | jq -r .transactionHash)
}

# read <rpc> <address> <signature> [args...]: the first word of a call's result.
read_call() {
  local rpc=$1; shift
  cast call --rpc-url "$rpc" "$@" | awk 'NR==1 {print $1}'
}

# wait_for <description> <expected> <rpc> <address> <signature> [args...]:
# polls a view until it returns <expected>, for up to 10 minutes.
wait_for() {
  local what=$1 expected=$2; shift 2
  echo "Waiting for $what (validators sign after the origin block is final, then the relayer delivers)..."
  local start=$SECONDS
  while (( SECONDS - start < 600 )); do
    if [ "$(read_call "$@")" = "$expected" ]; then
      echo "Delivered after $(( SECONDS - start )) s."
      return 0
    fi
    sleep 10
  done
  echo "Not delivered after 10 minutes. See https://github.com/recoil-labs/recoil-link (docs: Message debugging)." >&2
  exit 1
}

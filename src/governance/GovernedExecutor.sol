// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMessageRecipient} from "@recoillink/core/contracts/interfaces/IMessageRecipient.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";
import {Call} from "./Call.sol";

/// Lives on a remote chain. Makes the calls a CrossChainGovernor sends, and
/// nothing else: it accepts messages only from one governor on one chain.
/// Make this contract the owner of whatever it should govern.
contract GovernedExecutor is IMessageRecipient {
    address public immutable mailbox;
    uint32 public immutable governorDomain;
    bytes32 public immutable governor;

    event Executed(uint32 indexed origin, uint256 calls);

    constructor(address _mailbox, uint32 _governorDomain, address _governor) {
        mailbox = _mailbox;
        governorDomain = _governorDomain;
        governor = TypeCasts.addressToBytes32(_governor);
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata body) external payable override {
        require(msg.sender == mailbox, "only mailbox");
        // The trust check: a message counts only if it came from our governor on its home chain.
        require(origin == governorDomain && sender == governor, "untrusted sender");

        Call[] memory calls = abi.decode(body, (Call[]));
        for (uint256 i = 0; i < calls.length; i++) {
            // A failing call reverts the whole delivery; the relayer retries it later.
            (bool ok, bytes memory ret) = calls[i].target.call{value: calls[i].value}(calls[i].data);
            if (!ok) {
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
        emit Executed(origin, calls.length);
    }

    /// Calls may send value; fund the executor first.
    receive() external payable {}
}

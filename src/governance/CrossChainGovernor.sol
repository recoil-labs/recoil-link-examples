// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMailbox} from "@recoillink/core/contracts/interfaces/IMailbox.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";
import {Call} from "./Call.sol";

/// Lives on the home chain. Its owner (a DAO, a multisig) sends batches of
/// calls for a GovernedExecutor on another chain to make.
contract CrossChainGovernor {
    IMailbox public immutable mailbox;
    address public immutable owner;

    event ProposalSent(bytes32 indexed messageId, uint32 destination, address executor, uint256 calls);

    constructor(address _mailbox, address _owner) {
        mailbox = IMailbox(_mailbox);
        owner = _owner;
    }

    function quote(uint32 destination, address executor, Call[] calldata calls) external view returns (uint256) {
        return mailbox.quoteDispatch(destination, TypeCasts.addressToBytes32(executor), abi.encode(calls));
    }

    function execute(uint32 destination, address executor, Call[] calldata calls)
        external
        payable
        returns (bytes32 messageId)
    {
        require(msg.sender == owner, "only owner");
        bytes32 to = TypeCasts.addressToBytes32(executor);
        bytes memory body = abi.encode(calls);
        uint256 fee = mailbox.quoteDispatch(destination, to, body);
        require(msg.value >= fee, "fee too low");

        messageId = mailbox.dispatch{value: fee}(destination, to, body);
        emit ProposalSent(messageId, destination, executor, calls.length);

        if (msg.value > fee) {
            (bool ok,) = msg.sender.call{value: msg.value - fee}("");
            require(ok, "refund failed");
        }
    }
}

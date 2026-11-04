// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMessageRecipient} from "@recoillink/core/contracts/interfaces/IMessageRecipient.sol";

/// Receives text messages from any chain and keeps the latest one.
contract HelloReceiver is IMessageRecipient {
    address public immutable mailbox;

    uint32 public lastOrigin;
    bytes32 public lastSender;
    string public lastText;
    uint256 public received;

    event HelloReceived(uint32 indexed origin, bytes32 indexed sender, string text);

    constructor(address _mailbox) {
        mailbox = _mailbox;
    }

    /// Called by this chain's Mailbox once the message's proof checks out.
    function handle(uint32 origin, bytes32 sender, bytes calldata body) external payable override {
        // Only the Mailbox can deliver. Anyone else calling handle could fake a message.
        require(msg.sender == mailbox, "only mailbox");

        lastOrigin = origin;
        lastSender = sender;
        lastText = string(body);
        received++;
        emit HelloReceived(origin, sender, lastText);
    }
}

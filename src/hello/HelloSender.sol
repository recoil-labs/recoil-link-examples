// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMailbox} from "@recoillink/core/contracts/interfaces/IMailbox.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";

/// Sends a text message to a contract on another chain.
contract HelloSender {
    IMailbox public immutable mailbox;

    event HelloSent(bytes32 indexed messageId, uint32 destination, address recipient, string text);

    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }

    /// The fee to send `text`. Pass at least this as msg.value to sendHello.
    function quote(uint32 destination, address recipient, string calldata text) external view returns (uint256) {
        return mailbox.quoteDispatch(destination, TypeCasts.addressToBytes32(recipient), bytes(text));
    }

    function sendHello(uint32 destination, address recipient, string calldata text)
        external
        payable
        returns (bytes32 messageId)
    {
        bytes32 to = TypeCasts.addressToBytes32(recipient);
        uint256 fee = mailbox.quoteDispatch(destination, to, bytes(text));
        require(msg.value >= fee, "fee too low");

        // Pay exactly the quote: overpayment would be refunded to this contract, not the caller.
        messageId = mailbox.dispatch{value: fee}(destination, to, bytes(text));
        emit HelloSent(messageId, destination, recipient, text);

        if (msg.value > fee) {
            (bool ok,) = msg.sender.call{value: msg.value - fee}("");
            require(ok, "refund failed");
        }
    }
}

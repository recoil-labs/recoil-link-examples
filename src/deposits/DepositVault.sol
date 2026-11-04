// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMailbox} from "@recoillink/core/contracts/interfaces/IMailbox.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";

/// Lives on the origin chain. Takes native-token deposits and sends a proof of
/// each one to a DepositRegistry on another chain.
contract DepositVault {
    IMailbox public immutable mailbox;
    uint256 public nextDepositId;

    event Deposited(uint256 indexed depositId, address indexed depositor, uint256 amount, bytes32 messageId);

    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }

    function _body(uint256 depositId, address depositor, uint256 amount) internal pure returns (bytes memory) {
        return abi.encode(depositId, depositor, amount);
    }

    /// The message fee for a deposit proof. Send amount + this as msg.value.
    function quote(uint32 destination, address registry, uint256 amount) external view returns (uint256) {
        return mailbox.quoteDispatch(
            destination, TypeCasts.addressToBytes32(registry), _body(nextDepositId, msg.sender, amount)
        );
    }

    function deposit(uint32 destination, address registry, uint256 amount)
        external
        payable
        returns (uint256 depositId)
    {
        depositId = nextDepositId++;
        bytes32 to = TypeCasts.addressToBytes32(registry);
        bytes memory body = _body(depositId, msg.sender, amount);
        uint256 fee = mailbox.quoteDispatch(destination, to, body);
        require(msg.value >= amount + fee, "send amount + fee");

        bytes32 messageId = mailbox.dispatch{value: fee}(destination, to, body);
        emit Deposited(depositId, msg.sender, amount, messageId);

        uint256 excess = msg.value - amount - fee;
        if (excess > 0) {
            (bool ok,) = msg.sender.call{value: excess}("");
            require(ok, "refund failed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMessageRecipient} from "@recoillink/core/contracts/interfaces/IMessageRecipient.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";

/// Lives on the destination chain. Records deposits made in one DepositVault
/// on one origin chain, once each, so contracts here can act on them
/// (credit an account, mint a receipt, unlock a feature).
contract DepositRegistry is IMessageRecipient {
    address public immutable mailbox;
    uint32 public immutable vaultDomain;
    bytes32 public immutable vault;

    mapping(uint256 depositId => bool) public proven;
    mapping(address depositor => uint256) public creditOf;

    event DepositProven(uint256 indexed depositId, address indexed depositor, uint256 amount);

    constructor(address _mailbox, uint32 _vaultDomain, address _vault) {
        mailbox = _mailbox;
        vaultDomain = _vaultDomain;
        vault = TypeCasts.addressToBytes32(_vault);
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata body) external payable override {
        require(msg.sender == mailbox, "only mailbox");
        require(origin == vaultDomain && sender == vault, "untrusted sender");

        (uint256 depositId, address depositor, uint256 amount) = abi.decode(body, (uint256, address, uint256));
        // The Mailbox already delivers each message once; this guards against a vault bug too.
        require(!proven[depositId], "already proven");
        proven[depositId] = true;
        creditOf[depositor] += amount;
        emit DepositProven(depositId, depositor, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockMailbox} from "@recoillink/core/contracts/mock/MockMailbox.sol";
import {TestPostDispatchHook} from "@recoillink/core/contracts/test/TestPostDispatchHook.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";
import {IMailbox} from "@recoillink/core/contracts/interfaces/IMailbox.sol";
import {DepositVault} from "../src/deposits/DepositVault.sol";
import {DepositRegistry} from "../src/deposits/DepositRegistry.sol";

/// An attacker's contract: sends a made-up deposit proof without taking any money.
contract FakeVault {
    IMailbox immutable mailbox;

    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }

    function lie(uint32 destination, address registry, address beneficiary, uint256 amount) external {
        mailbox.dispatch(destination, TypeCasts.addressToBytes32(registry), abi.encode(uint256(0), beneficiary, amount));
    }
}

contract DepositsTest is Test {
    uint32 constant ORIGIN = 1;
    uint32 constant DESTINATION = 2;

    MockMailbox originMailbox;
    MockMailbox destinationMailbox;
    DepositVault vault;
    DepositRegistry registry;
    address alice = makeAddr("alice");

    function setUp() public {
        originMailbox = new MockMailbox(ORIGIN);
        destinationMailbox = new MockMailbox(DESTINATION);
        originMailbox.addRemoteMailbox(DESTINATION, destinationMailbox);

        vault = new DepositVault(address(originMailbox));
        registry = new DepositRegistry(address(destinationMailbox), ORIGIN, address(vault));
        vm.deal(alice, 10 ether);
    }

    function test_depositIsProvenOnDestination() public {
        vm.prank(alice);
        uint256 id = vault.deposit{value: 1 ether}(DESTINATION, address(registry), 1 ether);
        assertEq(address(vault).balance, 1 ether);
        assertFalse(registry.proven(id));

        destinationMailbox.processNextInboundMessage();
        assertTrue(registry.proven(id));
        assertEq(registry.creditOf(alice), 1 ether);
    }

    function test_feeIsChargedAndExcessRefunded() public {
        TestPostDispatchHook(address(originMailbox.requiredHook())).setFee(0.01 ether);
        vm.startPrank(alice);
        uint256 fee = vault.quote(DESTINATION, address(registry), 1 ether);
        vault.deposit{value: 1 ether + fee + 0.3 ether}(DESTINATION, address(registry), 1 ether);
        vm.stopPrank();

        assertEq(alice.balance, 10 ether - 1 ether - fee);
        assertEq(address(vault).balance, 1 ether);
    }

    function test_revertsWithoutAmountPlusFee() public {
        TestPostDispatchHook(address(originMailbox.requiredHook())).setFee(0.01 ether);
        vm.prank(alice);
        vm.expectRevert("send amount + fee");
        vault.deposit{value: 1 ether}(DESTINATION, address(registry), 1 ether);
    }

    function test_rejectsFakeVault() public {
        FakeVault fake = new FakeVault(address(originMailbox));
        fake.lie(DESTINATION, address(registry), alice, 1000 ether);
        vm.expectRevert("untrusted sender");
        destinationMailbox.processNextInboundMessage();
        assertEq(registry.creditOf(alice), 0);
    }

    function test_rejectsVaultOnAnotherChain() public {
        vm.prank(address(destinationMailbox));
        vm.expectRevert("untrusted sender");
        registry.handle(3, TypeCasts.addressToBytes32(address(vault)), abi.encode(uint256(0), alice, 1 ether));
    }

    function test_rejectsRepeatedProof() public {
        bytes memory body = abi.encode(uint256(0), alice, 1 ether);
        bytes32 sender = TypeCasts.addressToBytes32(address(vault));
        vm.startPrank(address(destinationMailbox));
        registry.handle(ORIGIN, sender, body);
        vm.expectRevert("already proven");
        registry.handle(ORIGIN, sender, body);
        vm.stopPrank();
        assertEq(registry.creditOf(alice), 1 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockMailbox} from "@recoillink/core/contracts/mock/MockMailbox.sol";
import {TestPostDispatchHook} from "@recoillink/core/contracts/test/TestPostDispatchHook.sol";
import {TypeCasts} from "@recoillink/core/contracts/libs/TypeCasts.sol";
import {HelloSender} from "../src/hello/HelloSender.sol";
import {HelloReceiver} from "../src/hello/HelloReceiver.sol";

contract HelloTest is Test {
    uint32 constant ORIGIN = 1;
    uint32 constant DESTINATION = 2;

    MockMailbox originMailbox;
    MockMailbox destinationMailbox;
    HelloSender sender;
    HelloReceiver receiver;

    function setUp() public {
        originMailbox = new MockMailbox(ORIGIN);
        destinationMailbox = new MockMailbox(DESTINATION);
        originMailbox.addRemoteMailbox(DESTINATION, destinationMailbox);

        sender = new HelloSender(address(originMailbox));
        receiver = new HelloReceiver(address(destinationMailbox));
    }

    function test_messageIsDelivered() public {
        sender.sendHello(DESTINATION, address(receiver), "hello from chain 1");
        destinationMailbox.processNextInboundMessage();

        assertEq(receiver.lastText(), "hello from chain 1");
        assertEq(receiver.lastOrigin(), ORIGIN);
        assertEq(receiver.lastSender(), TypeCasts.addressToBytes32(address(sender)));
        assertEq(receiver.received(), 1);
    }

    function test_feeIsChargedAndExcessRefunded() public {
        TestPostDispatchHook(address(originMailbox.requiredHook())).setFee(0.01 ether);
        uint256 fee = sender.quote(DESTINATION, address(receiver), "hi");
        assertGt(fee, 0);

        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.prank(user);
        sender.sendHello{value: fee + 0.5 ether}(DESTINATION, address(receiver), "hi");

        assertEq(user.balance, 1 ether - fee);
    }

    function test_revertsWhenFeeTooLow() public {
        TestPostDispatchHook(address(originMailbox.requiredHook())).setFee(0.01 ether);
        vm.expectRevert("fee too low");
        sender.sendHello{value: 0}(DESTINATION, address(receiver), "hi");
    }

    function test_onlyMailboxCanDeliver() public {
        vm.expectRevert("only mailbox");
        receiver.handle(ORIGIN, TypeCasts.addressToBytes32(address(this)), "forged");
    }
}

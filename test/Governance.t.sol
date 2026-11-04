// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockMailbox} from "@recoillink/core/contracts/mock/MockMailbox.sol";
import {CrossChainGovernor} from "../src/governance/CrossChainGovernor.sol";
import {GovernedExecutor} from "../src/governance/GovernedExecutor.sol";
import {Call} from "../src/governance/Call.sol";
import {ExampleSettings as Settings} from "../src/governance/ExampleSettings.sol";

contract GovernanceTest is Test {
    uint32 constant HOME = 1;
    uint32 constant REMOTE = 2;

    MockMailbox homeMailbox;
    MockMailbox remoteMailbox;
    CrossChainGovernor governor;
    GovernedExecutor executor;
    Settings settings;
    address dao = makeAddr("dao");

    function setUp() public {
        homeMailbox = new MockMailbox(HOME);
        remoteMailbox = new MockMailbox(REMOTE);
        homeMailbox.addRemoteMailbox(REMOTE, remoteMailbox);

        governor = new CrossChainGovernor(address(homeMailbox), dao);
        executor = new GovernedExecutor(address(remoteMailbox), HOME, address(governor));
        settings = new Settings(address(executor));
    }

    function _setFee(uint256 bps) internal pure returns (Call[] memory calls) {
        calls = new Call[](1);
        calls[0] = Call({target: address(0), value: 0, data: abi.encodeCall(Settings.setFeeBps, (bps))});
    }

    function _send(CrossChainGovernor from, uint256 bps) internal {
        Call[] memory calls = _setFee(bps);
        calls[0].target = address(settings);
        vm.prank(dao);
        from.execute(REMOTE, address(executor), calls);
    }

    function test_governorChangesRemoteSetting() public {
        _send(governor, 25);
        remoteMailbox.processNextInboundMessage();
        assertEq(settings.feeBps(), 25);
    }

    function test_rejectsLookalikeGovernor() public {
        CrossChainGovernor impostor = new CrossChainGovernor(address(homeMailbox), dao);
        _send(impostor, 25);
        vm.expectRevert("untrusted sender");
        remoteMailbox.processNextInboundMessage();
        assertEq(settings.feeBps(), 0);
    }

    function test_rejectsGovernorOnAnotherChain() public {
        // The real governor's address, but the message claims to come from chain 3.
        Call[] memory calls = _setFee(25);
        calls[0].target = address(settings);
        vm.prank(address(remoteMailbox));
        vm.expectRevert("untrusted sender");
        executor.handle(3, bytes32(uint256(uint160(address(governor)))), abi.encode(calls));
    }

    function test_onlyOwnerCanPropose() public {
        Call[] memory calls = _setFee(25);
        calls[0].target = address(settings);
        vm.expectRevert("only owner");
        governor.execute(REMOTE, address(executor), calls);
    }

    function test_failingCallRevertsDelivery() public {
        _send(governor, 5000); // above the 1000 limit
        vm.expectRevert("too high");
        remoteMailbox.processNextInboundMessage();
        assertEq(settings.feeBps(), 0);
    }
}

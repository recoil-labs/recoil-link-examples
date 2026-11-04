// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// A stand-in for whatever the executor governs: a fee setting only its owner may change.
contract ExampleSettings {
    address public immutable owner;
    uint256 public feeBps;

    event FeeChanged(uint256 feeBps);

    constructor(address _owner) {
        owner = _owner;
    }

    function setFeeBps(uint256 bps) external {
        require(msg.sender == owner, "not owner");
        require(bps <= 1000, "too high");
        feeBps = bps;
        emit FeeChanged(bps);
    }
}

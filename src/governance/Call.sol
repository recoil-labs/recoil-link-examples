// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// One call for the executor to make on the destination chain.
struct Call {
    address target;
    uint256 value;
    bytes data;
}

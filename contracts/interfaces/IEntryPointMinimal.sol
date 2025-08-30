// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Minimal subset of EntryPoint functions used for deposit management.
interface IEntryPointMinimal {
    function depositTo(address account) external payable;
    function balanceOf(address account) external view returns (uint256);
    function withdrawTo(address payable withdrawAddress, uint256 amount) external;
}

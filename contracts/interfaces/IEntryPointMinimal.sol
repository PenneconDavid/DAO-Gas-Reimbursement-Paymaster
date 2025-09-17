// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// Minimal subset of EntryPoint functions used for deposit and stake management.
interface IEntryPointMinimal {
    // Deposit
    function depositTo(address account) external payable;
    function balanceOf(address account) external view returns (uint256);
    function withdrawTo(address payable withdrawAddress, uint256 amount) external;

    // Stake
    function addStake(uint32 unstakeDelaySec) external payable;
    function unlockStake() external;
    function withdrawStake(address payable withdrawAddress) external;
}

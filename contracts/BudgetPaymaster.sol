// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "openzeppelin/contracts/utils/Pausable.sol";

import {IEntryPointMinimal} from "./interfaces/IEntryPointMinimal.sol";
import {Config} from "./Config.sol";

/// BudgetPaymaster (skeleton for M0 scaffolding)
/// - AccessControl roles (ADMIN, PAUSER)
/// - Per-sender budget storage (limit, used, epochIndex)
/// - receive() auto-deposits ETH into EntryPoint deposit
/// - Admin withdraw helper from EntryPoint deposit
contract BudgetPaymaster is AccessControl, Pausable {
    // --------------------
    // Roles
    // --------------------
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --------------------
    // Types & storage
    // --------------------
    struct Budget {
        uint128 limitWei;      // monthly allowance in wei
        uint128 usedWei;       // used amount in current epoch
        uint32 epochIndex;     // YYYY*12 + MM
    }

    /// EntryPoint v0.8 deposit management
    IEntryPointMinimal public immutable entryPoint;

    /// Treasury address where withdrawals are sent
    address public treasury;

    /// Allowlisted SimpleAccount factory for sponsoring deployments (set but unused in skeleton)
    address public simpleAccountFactory;

    /// Per-sender budgets
    mapping(address => Budget) private _budgets;

    // --------------------
    // Events
    // --------------------
    event BudgetSet(address indexed account, uint256 limitWei);
    event DepositAdded(address indexed from, uint256 amount);
    event DepositWithdrawn(address indexed to, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    event SimpleAccountFactoryUpdated(address indexed newFactory);

    // --------------------
    // Errors
    // --------------------
    error BudgetBelowUsed();
    error InvalidTreasury();

    // --------------------
    // Constructor
    // --------------------
    constructor(
        address entryPointAddress,
        address admin,
        address treasuryAddress,
        address simpleAccountFactoryAddress
    ) {
        require(entryPointAddress != address(0), "entryPoint");
        require(admin != address(0), "admin");
        require(treasuryAddress != address(0), "treasury");

        entryPoint = IEntryPointMinimal(entryPointAddress);
        treasury = treasuryAddress;
        simpleAccountFactory = simpleAccountFactoryAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    // --------------------
    // Receive & deposit management
    // --------------------

    /// Auto-deposit any received ETH into EntryPoint on behalf of this paymaster
    receive() external payable {
        if (msg.value > 0) {
            entryPoint.depositTo{value: msg.value}(address(this));
            emit DepositAdded(msg.sender, msg.value);
        }
    }

    /// View the current EntryPoint deposit balance for this paymaster
    function entryPointDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /// Withdraw ETH from EntryPoint deposit to the configured treasury
    function withdrawFunds(uint256 amount) external onlyRole(ADMIN_ROLE) {
        address payable to = payable(treasury);
        if (to == address(0)) revert InvalidTreasury();
        entryPoint.withdrawTo(to, amount);
        emit DepositWithdrawn(to, amount);
    }

    /// Update the treasury address
    function setTreasury(address newTreasury) external onlyRole(ADMIN_ROLE) {
        if (newTreasury == address(0)) revert InvalidTreasury();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /// Update the allowlisted SimpleAccount factory
    function setSimpleAccountFactory(address newFactory) external onlyRole(ADMIN_ROLE) {
        simpleAccountFactory = newFactory;
        emit SimpleAccountFactoryUpdated(newFactory);
    }

    // --------------------
    // Pause controls
    // --------------------

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // --------------------
    // Budget admin API (stubs for M0)
    // --------------------

    function setBudget(address account, uint128 monthlyLimitWei) external onlyRole(ADMIN_ROLE) {
        Budget storage b = _budgets[account];
        // Disallow lowering below current used to avoid ambiguity
        if (monthlyLimitWei < b.usedWei) revert BudgetBelowUsed();
        b.limitWei = monthlyLimitWei;
        emit BudgetSet(account, monthlyLimitWei);
    }

    function getBudget(address account) external view returns (uint128 limitWei, uint128 usedWei, uint32 epochIndex) {
        Budget storage b = _budgets[account];
        return (b.limitWei, b.usedWei, b.epochIndex);
    }

    // --------------------
    // Epoch helpers (to be completed in M0 accounting step)
    // --------------------

    function _currentEpochIndex(uint256 timestamp) internal pure returns (uint32) {
        // Placeholder: will be replaced with proper YYYY*12 + MM computation.
        // Returning 0 keeps skeleton compilable and non-functional for accounting.
        timestamp; // silence unused warning
        return 0;
    }
}

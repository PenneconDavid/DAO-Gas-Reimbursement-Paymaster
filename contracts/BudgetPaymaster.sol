// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "openzeppelin/contracts/utils/Pausable.sol";

import {IEntryPointMinimal} from "./interfaces/IEntryPointMinimal.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";
import {Config} from "./Config.sol";
import {IReceiptNFT} from "./interfaces/IReceiptNFT.sol";

/// BudgetPaymaster (M0/M1)
/// - AccessControl roles (ADMIN, PAUSER)
/// - Per-sender budgets with calendar-month UTC epoching (YYYY*12+MM)
/// - Sender-allowlist via budget limit > 0
/// - Per-op safety caps (gas, gas price, worst-case wei) [admin-settable]
/// - Optional global monthly cap across all users [M1]
/// - receive() auto-deposits ETH into EntryPoint deposit
/// - Admin withdraw/stake helpers
contract BudgetPaymaster is AccessControl, Pausable, IPaymaster {
    using UserOperationLib for PackedUserOperation;

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
    IEntryPointMinimal public immutable ENTRY_POINT;

    /// Treasury address where withdrawals are sent
    address public treasury;

    /// Allowlisted SimpleAccount factory for sponsoring deployments
    address public simpleAccountFactory;

    /// Per-sender budgets
    mapping(address => Budget) private _budgets;

    /// Global monthly cap (optional)
    uint128 public globalLimitWei;      // 0 means disabled
    uint128 public globalUsedWei;
    uint32 public globalEpochIndex;

    /// Admin-settable caps
    uint256 public maxVerificationGas = Config.MAX_VERIFICATION_GAS;
    uint256 public maxCallGas = Config.MAX_CALL_GAS;
    uint256 public maxPostOpGas = Config.MAX_POST_OP_GAS;
    uint256 public absoluteMaxFeeGwei = Config.ABSOLUTE_MAX_FEE_GWEI;
    uint256 public basefeeMultiplier = Config.BASEFEE_MULTIPLIER;
    uint256 public maxWeiPerOp = Config.MAX_WEI_PER_OP;

    /// Receipt NFT (optional)
    IReceiptNFT public receiptNFT;

    // --------------------
    // Events
    // --------------------
    event BudgetSet(address indexed account, uint256 limitWei);
    event BudgetCharged(address indexed account, uint256 amountWei, uint256 newUsedWei, uint256 remainingWei);
    event EpochRollover(address indexed account, uint32 newEpochIndex);
    event GlobalBudgetSet(uint256 limitWei);
    event GlobalBudgetCharged(uint256 amountWei, uint256 newUsedWei, uint256 remainingWei);
    event GlobalEpochRollover(uint32 newEpochIndex);
    event CapsUpdated(uint256 maxVerificationGas, uint256 maxCallGas, uint256 maxPostOpGas);
    event FeeCapsUpdated(uint256 absoluteMaxFeeGwei, uint256 basefeeMultiplier);
    event MaxWeiPerOpUpdated(uint256 maxWeiPerOp);
    event DepositAdded(address indexed from, uint256 amount);
    event DepositWithdrawn(address indexed to, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    event SimpleAccountFactoryUpdated(address indexed newFactory);
    event ReceiptNFTUpdated(address indexed nft);

    // --------------------
    // Errors
    // --------------------
    error BudgetBelowUsed();
    error InvalidTreasury();
    error NotFromEntryPoint();
    error PaymasterPaused();
    error NotAllowlistedSender();
    error OverOpCaps();
    error FactoryNotAllowlisted();

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

        ENTRY_POINT = IEntryPointMinimal(entryPointAddress);
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
            ENTRY_POINT.depositTo{value: msg.value}(address(this));
            emit DepositAdded(msg.sender, msg.value);
        }
    }

    /// View the current EntryPoint deposit balance for this paymaster
    function entryPointDeposit() external view returns (uint256) {
        return ENTRY_POINT.balanceOf(address(this));
    }

    /// Withdraw ETH from EntryPoint deposit to the configured treasury
    function withdrawFunds(uint256 amount) external onlyRole(ADMIN_ROLE) {
        address payable to = payable(treasury);
        if (to == address(0)) revert InvalidTreasury();
        ENTRY_POINT.withdrawTo(to, amount);
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

    /// Update the receipt NFT contract
    function setReceiptNFT(address nft) external onlyRole(ADMIN_ROLE) {
        receiptNFT = IReceiptNFT(nft);
        emit ReceiptNFTUpdated(nft);
    }

    // --------------------
    // Pause controls
    // --------------------

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    // --------------------
    // Budget admin API
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

    function setGlobalMonthlyCap(uint128 limitWei) external onlyRole(ADMIN_ROLE) {
        // If lowering below used, cap will be effectively fully spent until next rollover
        globalLimitWei = limitWei;
        emit GlobalBudgetSet(limitWei);
    }

    function setOpCaps(uint256 _maxVerificationGas, uint256 _maxCallGas, uint256 _maxPostOpGas) external onlyRole(ADMIN_ROLE) {
        maxVerificationGas = _maxVerificationGas;
        maxCallGas = _maxCallGas;
        maxPostOpGas = _maxPostOpGas;
        emit CapsUpdated(_maxVerificationGas, _maxCallGas, _maxPostOpGas);
    }

    function setFeeCaps(uint256 _absoluteMaxFeeGwei, uint256 _basefeeMultiplier) external onlyRole(ADMIN_ROLE) {
        absoluteMaxFeeGwei = _absoluteMaxFeeGwei;
        basefeeMultiplier = _basefeeMultiplier;
        emit FeeCapsUpdated(_absoluteMaxFeeGwei, _basefeeMultiplier);
    }

    function setMaxWeiPerOp(uint256 _maxWeiPerOp) external onlyRole(ADMIN_ROLE) {
        maxWeiPerOp = _maxWeiPerOp;
        emit MaxWeiPerOpUpdated(_maxWeiPerOp);
    }

    // --------------------
    // Epoch helpers (calendar month UTC)
    // --------------------

    // Convert a timestamp (seconds) to (year, month) using a civil-from-days algorithm.
    function _yearMonthFromTimestamp(uint256 timestamp) internal pure returns (uint32 year, uint32 month) {
        int256 z = int256(timestamp / 86400);
        z += 719468; // shift to civil-from-days epoch
        int256 era = (z >= 0 ? z : z - 146096) / 146097;
        int256 doe = z - era * 146097;                                // [0, 146096]
        int256 yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365; // [0, 399]
        int256 y = yoe + era * 400;
        int256 doy = doe - (365*yoe + yoe/4 - yoe/100 + yoe/400);     // [0, 365]
        int256 mp = (5*doy + 2)/153;                                  // [0, 11]
        int256 d = doy - (153*mp + 2)/5 + 1;                          // [1, 31]
        int256 m = mp + (mp < 10 ? int256(3) : int256(-9));           // [1, 12]
        y = y + (m <= 2 ? int256(1) : int256(0));
        year = uint32(uint256(y));
        month = uint32(uint256(m));
        d; // silence unused local
    }

    function _currentEpochIndex(uint256 timestamp) internal pure returns (uint32) {
        (uint32 y, uint32 m) = _yearMonthFromTimestamp(timestamp);
        // epochIndex = year*12 + month
        return y * 12 + m;
    }

    // --------------------
    // Internal helpers
    // --------------------

    function _requireFromEntryPoint() internal view {
        if (msg.sender != address(ENTRY_POINT)) revert NotFromEntryPoint();
    }

    function _lazyRollover(address account, Budget storage b) internal {
        uint32 nowEpoch = _currentEpochIndex(block.timestamp);
        if (b.epochIndex != nowEpoch) {
            b.epochIndex = nowEpoch;
            b.usedWei = 0;
            emit EpochRollover(account, nowEpoch);
        }
    }

    function _lazyRolloverGlobal() internal {
        uint32 nowEpoch = _currentEpochIndex(block.timestamp);
        if (globalEpochIndex != nowEpoch) {
            globalEpochIndex = nowEpoch;
            globalUsedWei = 0;
            emit GlobalEpochRollover(nowEpoch);
        }
    }

    // --------------------
    // ERC-4337 hooks (M0/M1)
    // --------------------

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        _requireFromEntryPoint();
        if (paused()) revert PaymasterPaused();

        address account = userOp.sender;
        Budget storage b = _budgets[account];
        _lazyRollover(account, b);
        _lazyRolloverGlobal();

        if (b.limitWei == 0) revert NotAllowlistedSender();

        // Enforce per-op gas caps
        uint256 verificationGas = userOp.unpackVerificationGasLimit();
        uint256 callGas = userOp.unpackCallGasLimit();
        uint256 postOpGas = userOp.unpackPostOpGasLimit();
        if (verificationGas > maxVerificationGas || callGas > maxCallGas || postOpGas > maxPostOpGas) revert OverOpCaps();

        // Enforce gas price caps
        uint256 maxFeePerGas = userOp.unpackMaxFeePerGas();
        uint256 maxPriorityFeePerGas = userOp.unpackMaxPriorityFeePerGas();
        if (maxFeePerGas > absoluteMaxFeeGwei * 1 gwei) revert OverOpCaps();
        if (block.basefee > 0) {
            if (maxFeePerGas > (basefeeMultiplier * block.basefee + maxPriorityFeePerGas)) revert OverOpCaps();
        }

        // initCode factory allowlist (for sponsored deployments)
        if (userOp.initCode.length != 0) {
            if (simpleAccountFactory == address(0)) revert FactoryNotAllowlisted();
            if (userOp.initCode.length < 20) revert FactoryNotAllowlisted();
            address factory = address(bytes20(userOp.initCode[0:20]));
            if (factory != simpleAccountFactory) revert FactoryNotAllowlisted();
        }

        // Remaining budget checks
        uint256 remaining = uint256(b.limitWei) - uint256(b.usedWei);
        if (maxCost > remaining) revert OverOpCaps();
        if (maxCost > maxWeiPerOp) revert OverOpCaps();

        // Global cap check (if enabled)
        if (globalLimitWei != 0) {
            uint256 globalRemaining = uint256(globalLimitWei) - uint256(globalUsedWei);
            if (maxCost > globalRemaining) revert OverOpCaps();
        }

        // Pass sender and userOpHash in context for postOp accounting and optional receipt
        return (abi.encode(account, userOpHash), 0);
    }

    function postOp(
        PostOpMode /*mode*/,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) external override {
        _requireFromEntryPoint();

        (address account, bytes32 userOpHash) = abi.decode(context, (address, bytes32));
        Budget storage b = _budgets[account];
        _lazyRollover(account, b);
        _lazyRolloverGlobal();

        // Charge actual cost (clamped into uint128)
        uint128 charge = actualGasCost > type(uint128).max ? type(uint128).max : uint128(actualGasCost);
        uint256 newUsed = uint256(b.usedWei) + uint256(charge);
        if (newUsed > type(uint128).max) { newUsed = type(uint128).max; }
        b.usedWei = uint128(newUsed);
        uint256 remaining = uint256(b.limitWei) - uint256(b.usedWei);
        emit BudgetCharged(account, charge, b.usedWei, remaining);

        // Global accounting (if enabled)
        if (globalLimitWei != 0) {
            uint256 gNewUsed = uint256(globalUsedWei) + uint256(charge);
            if (gNewUsed > type(uint128).max) { gNewUsed = type(uint128).max; }
            globalUsedWei = uint128(gNewUsed);
            uint256 gRemaining = uint256(globalLimitWei) - uint256(globalUsedWei);
            emit GlobalBudgetCharged(charge, globalUsedWei, gRemaining);
        }

        // Optional receipt mint
        if (address(receiptNFT) != address(0) && charge > 0) {
            receiptNFT.mintReceipt(account, userOpHash, charge, _currentEpochIndex(block.timestamp));
        }
    }

    // --------------------
    // Stake & deposit admin
    // --------------------

    /// Admin deposits ETH into EntryPoint on behalf of this paymaster
    function deposit() external payable onlyRole(ADMIN_ROLE) {
        if (msg.value > 0) {
            ENTRY_POINT.depositTo{value: msg.value}(address(this));
            emit DepositAdded(msg.sender, msg.value);
        }
    }

    /// Admin adds stake with an unstake delay (seconds)
    function addStake(uint32 unstakeDelaySec) external payable onlyRole(ADMIN_ROLE) {
        ENTRY_POINT.addStake{value: msg.value}(unstakeDelaySec);
    }

    /// Admin unlocks stake to start the withdrawal timer
    function unlockStake() external onlyRole(ADMIN_ROLE) { ENTRY_POINT.unlockStake(); }

    /// Admin withdraws unlocked stake to treasury
    function withdrawStake() external onlyRole(ADMIN_ROLE) { ENTRY_POINT.withdrawStake(payable(treasury)); }
}

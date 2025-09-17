// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Config {
    // Per-operation gas ceilings
    uint256 internal constant MAX_CALL_GAS = 1_000_000;
    uint256 internal constant MAX_POST_OP_GAS = 120_000;
    uint256 internal constant MAX_VERIFICATION_GAS = 120_000;

    // Gas price rules
    uint256 internal constant ABSOLUTE_MAX_FEE_GWEI = 150; // 150 gwei
    uint256 internal constant BASEFEE_MULTIPLIER = 3; // <= 3x basefee + tip

    // Budgets
    uint256 internal constant DEFAULT_MONTHLY_BUDGET_WEI = 0.05 ether;
    uint256 internal constant MAX_WEI_PER_OP = 0.01 ether;

    // Global cap (enabled in M1)
    uint256 internal constant DEFAULT_GLOBAL_MONTHLY_CAP_WEI = 0.5 ether;
}

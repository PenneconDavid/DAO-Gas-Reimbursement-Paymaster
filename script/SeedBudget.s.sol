// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";

contract SeedBudget is Script {
    function run() external {
        address pmAddr = vm.envAddress("PAYMASTER_ADDRESS");
        address account = vm.envAddress("BUDGET_ACCOUNT");
        uint256 limitWei = vm.envUint("BUDGET_LIMIT_WEI");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        BudgetPaymaster pm = BudgetPaymaster(payable(pmAddr));

        vm.startBroadcast(admin);
        pm.setBudget(account, uint128(limitWei));
        vm.stopBroadcast();

        console2.log("Budget set:", account, limitWei);
    }
}

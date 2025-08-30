// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";

contract SetGlobalCap is Script {
    function run() external {
        address pmAddr = vm.envAddress("PAYMASTER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        uint256 limitWei = vm.envUint("GLOBAL_LIMIT_WEI");

        BudgetPaymaster pm = BudgetPaymaster(payable(pmAddr));
        vm.startBroadcast(admin);
        pm.setGlobalMonthlyCap(uint128(limitWei));
        vm.stopBroadcast();

        console2.log("Global monthly cap set:", limitWei);
    }
}

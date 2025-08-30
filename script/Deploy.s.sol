// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";
import {GovActions} from "contracts/GovActions.sol";

contract Deploy is Script {
    function run() external {
        // Read env
        address entryPoint = vm.envAddress("ENTRYPOINT_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address simpleAccountFactory = vm.envAddress("SIMPLE_ACCOUNT_FACTORY");

        vm.startBroadcast();
        GovActions gov = new GovActions();
        BudgetPaymaster pm = new BudgetPaymaster(entryPoint, admin, treasury, simpleAccountFactory);
        vm.stopBroadcast();

        console2.log("GovActions:", address(gov));
        console2.log("BudgetPaymaster:", address(pm));
    }
}

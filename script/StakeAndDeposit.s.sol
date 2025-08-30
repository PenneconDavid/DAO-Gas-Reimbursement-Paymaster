// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";

contract StakeAndDeposit is Script {
    function run() external {
        address pmAddr = vm.envAddress("PAYMASTER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        uint32 unstakeDelaySec = uint32(vm.envUint("UNSTAKE_DELAY_SEC"));
        uint256 stakeAmount = vm.envUint("STAKE_AMOUNT_WEI");
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT_WEI");

        BudgetPaymaster pm = BudgetPaymaster(payable(pmAddr));

        vm.startBroadcast(admin);
        // add stake
        (bool ok1,) = address(pm).call{value: stakeAmount}(abi.encodeWithSelector(pm.addStake.selector, unstakeDelaySec));
        require(ok1, "addStake failed");
        // deposit
        (bool ok2,) = address(pm).call{value: depositAmount}(abi.encodeWithSelector(pm.deposit.selector));
        require(ok2, "deposit failed");
        vm.stopBroadcast();

        console2.log("Stake added:", stakeAmount, "deposit:", depositAmount);
    }
}

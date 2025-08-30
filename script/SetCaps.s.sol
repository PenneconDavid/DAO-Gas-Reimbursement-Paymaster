// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";

contract SetCaps is Script {
    function run() external {
        address pmAddr = vm.envAddress("PAYMASTER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        uint256 maxVerificationGas = vm.envOr("MAX_VERIFICATION_GAS", uint256(120_000));
        uint256 maxCallGas = vm.envOr("MAX_CALL_GAS", uint256(1_000_000));
        uint256 maxPostOpGas = vm.envOr("MAX_POSTOP_GAS", uint256(120_000));
        uint256 absoluteMaxFeeGwei = vm.envOr("ABSOLUTE_MAX_FEE_GWEI", uint256(150));
        uint256 basefeeMultiplier = vm.envOr("BASEFEE_MULTIPLIER", uint256(3));
        uint256 maxWeiPerOp = vm.envOr("MAX_WEI_PER_OP", uint256(0.01 ether));

        BudgetPaymaster pm = BudgetPaymaster(payable(pmAddr));

        vm.startBroadcast(admin);
        pm.setOpCaps(maxVerificationGas, maxCallGas, maxPostOpGas);
        pm.setFeeCaps(absoluteMaxFeeGwei, basefeeMultiplier);
        pm.setMaxWeiPerOp(maxWeiPerOp);
        vm.stopBroadcast();

        console2.log("Caps updated");
    }
}

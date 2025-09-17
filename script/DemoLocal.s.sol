// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";
import {GovActions} from "contracts/GovActions.sol";
import {MockEntryPointDemo} from "contracts/demo/MockEntryPointDemo.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";

contract DemoLocal is Script {
    using UserOperationLib for PackedUserOperation;

    function run() external {
        address admin = vm.envOr("ADMIN_ADDRESS", address(this));
        address treasury = vm.envOr("TREASURY_ADDRESS", address(this));
        address user = vm.envOr("DEMO_SENDER", address(0xCAFE));

        vm.startBroadcast(admin);
        // Deploy mock EP, paymaster, gov
        MockEntryPointDemo ep = new MockEntryPointDemo();
        GovActions gov = new GovActions();
        BudgetPaymaster pm = new BudgetPaymaster(address(ep), admin, treasury, address(0));
        pm.setBudget(user, 0.05 ether);
        // fund EP to simulate deposit/withdraw
        (bool ok,) = address(ep).call{value: 1 ether}(hex"");
        require(ok, "fund ep");
        vm.stopBroadcast();

        // Build a minimal userOp (not executed, just validation+postOp path)
        PackedUserOperation memory uo;
        uo.sender = user;
        uo.nonce = 0;
        uo.initCode = hex"";
        uo.callData = hex""; // not used in our validation path
        uo.accountGasLimits = bytes32((uint256(80_000) << 128) | uint256(200_000));
        uo.preVerificationGas = 50_000;
        uo.gasFees = bytes32((uint256(1 gwei) << 128) | uint256(20 gwei));
        uo.paymasterAndData = abi.encodePacked(bytes20(address(pm)), bytes16(uint128(100_000)), bytes16(uint128(80_000)));
        uo.signature = hex"11";

        // Simulate validate + postOp
        (bytes memory ctx,) = ep.callValidate(pm, uo, 0.002 ether);
        ep.callPostOp(pm, IPaymaster.PostOpMode.opSucceeded, ctx, 0.001 ether);

        // Read and log budget result
        (uint128 limit, uint128 used, uint32 epoch) = pm.getBudget(user);
        console2.log("Budget:", limit, used, epoch);
        console2.log("Demo done (local validate+postOp simulated)");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";
import {IEntryPointMinimal} from "contracts/interfaces/IEntryPointMinimal.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";

contract MockEntryPoint is Test, IEntryPointMinimal {
    address public paymaster;

    constructor(address _paymaster) {
        paymaster = _paymaster;
    }

    receive() external payable {}

    function depositTo(address account) external payable override {
        // noop for tests
        account; // silence
    }

    function balanceOf(address account) external view override returns (uint256) {
        account;
        return address(this).balance;
    }

    function withdrawTo(address payable withdrawAddress, uint256 amount) external override {
        (bool ok,) = withdrawAddress.call{value: amount}(hex"");
        require(ok, "withdraw fail");
    }

    // Helpers to call paymaster hooks
    function callValidate(
        BudgetPaymaster pm,
        PackedUserOperation calldata userOp,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData) {
        vm.prank(address(this));
        (context, validationData) = pm.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
    }

    function callPostOp(
        BudgetPaymaster pm,
        IPaymaster.PostOpMode mode,
        bytes memory context,
        uint256 actualGasCost
    ) external {
        vm.prank(address(this));
        pm.postOp(mode, context, actualGasCost, 0);
    }
}

contract BudgetPaymasterTest is Test {
    using UserOperationLib for PackedUserOperation;

    BudgetPaymaster pm;
    MockEntryPoint ep;

    address ADMIN = address(0xA11CE);
    address TREASURY = address(0xBEEF);
    address SENDER = address(0xCAFE);
    address FACTORY = address(0xFACA7E);

    function setUp() public {
        // deploy a dummy pm with temporary entrypoint address; we replace after deploy
        pm = new BudgetPaymaster(address(0xdead), ADMIN, TREASURY, FACTORY);
        // replace immutable: deploy a new mock EP and redeploy pm with its address
        ep = new MockEntryPoint(address(pm));
        pm = new BudgetPaymaster(address(ep), ADMIN, TREASURY, FACTORY);

        // fund EP for withdraw tests
        vm.deal(address(ep), 100 ether);

        // grant roles already set to ADMIN in constructor
        vm.startPrank(ADMIN);
        pm.setBudget(SENDER, 0.05 ether);
        vm.stopPrank();
    }

    function _baseUserOp(address sender) internal view returns (PackedUserOperation memory uo) {
        uo.sender = sender;
        uo.nonce = 0;
        uo.initCode = hex"";
        uo.callData = hex"";
        uo.accountGasLimits = bytes32((uint256(80_000) << 128) | uint256(200_000));
        uo.preVerificationGas = 50_000;
        // gasFees = [maxPriority (hi 128) | maxFee (lo 128)]
        uint256 maxPrio = 1 gwei;
        uint256 maxFee = 30 gwei;
        uo.gasFees = bytes32((maxPrio << 128) | maxFee);
        // paymasterAndData static fields
        bytes memory pmd = abi.encodePacked(
            bytes20(address(pm)),
            bytes16(uint128(100_000)),
            bytes16(uint128(80_000))
        );
        uo.paymasterAndData = pmd;
        uo.signature = hex"11"; // unused here
    }

    function test_happyPath_chargeBudget() public {
        PackedUserOperation memory uo = _baseUserOp(SENDER);
        // simulate caller as EntryPoint
        vm.startPrank(address(ep));
        (bytes memory ctx,) = pm.validatePaymasterUserOp(uo, bytes32(0), 0.005 ether);
        pm.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, 0.004 ether, 0);
        vm.stopPrank();

        (uint128 limit, uint128 used, ) = pm.getBudget(SENDER);
        assertEq(limit, 0.05 ether);
        assertEq(used, 0.004 ether);
    }

    function test_reject_notAllowlisted() public {
        PackedUserOperation memory uo = _baseUserOp(address(0xABCD));
        vm.prank(address(ep));
        vm.expectRevert(BudgetPaymaster.NotAllowlistedSender.selector);
        pm.validatePaymasterUserOp(uo, bytes32(0), 0.001 ether);
    }

    function test_epoch_rollover_lazy() public {
        // 2025-01-31 23:59:59 UTC
        vm.warp(1735689599);
        PackedUserOperation memory uo = _baseUserOp(SENDER);
        vm.startPrank(address(ep));
        (bytes memory ctx,) = pm.validatePaymasterUserOp(uo, bytes32(0), 0.001 ether);
        pm.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, 0.001 ether, 0);
        vm.stopPrank();
        (, uint128 usedBefore, uint32 epochBefore) = pm.getBudget(SENDER);
        assertGt(usedBefore, 0);

        // next second: new month
        vm.warp(1735689600);
        vm.startPrank(address(ep));
        (ctx,) = pm.validatePaymasterUserOp(uo, bytes32(0), 0.001 ether);
        pm.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, 0.001 ether, 0);
        vm.stopPrank();
        (, uint128 usedAfter, uint32 epochAfter) = pm.getBudget(SENDER);
        assertEq(epochAfter, epochBefore + 1);
        assertEq(usedAfter, 0.001 ether);
    }

    function test_revert_charged() public {
        PackedUserOperation memory uo = _baseUserOp(SENDER);
        vm.startPrank(address(ep));
        (bytes memory ctx,) = pm.validatePaymasterUserOp(uo, bytes32(0), 0.003 ether);
        pm.postOp(IPaymaster.PostOpMode.opReverted, ctx, 0.002 ether, 0);
        vm.stopPrank();
        (, uint128 used, ) = pm.getBudget(SENDER);
        assertEq(used, 0.002 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPointMinimal} from "contracts/interfaces/IEntryPointMinimal.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

contract MockEntryPointDemo is IEntryPointMinimal {
    receive() external payable {}

    function depositTo(address /*account*/ ) external payable override { }
    function balanceOf(address /*account*/ ) external view override returns (uint256) { return address(this).balance; }
    function withdrawTo(address payable withdrawAddress, uint256 amount) external override {
        (bool ok,) = withdrawAddress.call{value: amount}(hex"");
        require(ok, "withdraw fail");
    }
    function addStake(uint32 /*unstakeDelaySec*/ ) external payable override { }
    function unlockStake() external override { }
    function withdrawStake(address payable withdrawAddress) external override {
        (bool ok,) = withdrawAddress.call{value: address(this).balance}(hex"");
        require(ok, "withdraw stake fail");
    }

    function callValidate(BudgetPaymaster pm, PackedUserOperation calldata userOp, uint256 maxCost)
        external
        returns (bytes memory context, uint256 validationData)
    {
        (context, validationData) = pm.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
    }

    function callPostOp(BudgetPaymaster pm, IPaymaster.PostOpMode mode, bytes memory context, uint256 actualGasCost) external {
        pm.postOp(mode, context, actualGasCost, 0);
    }
}

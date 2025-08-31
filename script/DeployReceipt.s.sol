// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {BudgetPaymaster} from "contracts/BudgetPaymaster.sol";
import {ReceiptNFT} from "contracts/ReceiptNFT.sol";

contract DeployReceipt is Script {
    function run() external {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address pmAddr = vm.envAddress("PAYMASTER_ADDRESS");

        vm.startBroadcast(admin);
        ReceiptNFT nft = new ReceiptNFT(admin);
        nft.grantRole(nft.MINTER_ROLE(), pmAddr);
        BudgetPaymaster(pmAddr).setReceiptNFT(address(nft));
        vm.stopBroadcast();

        console2.log("ReceiptNFT:", address(nft));
    }
}

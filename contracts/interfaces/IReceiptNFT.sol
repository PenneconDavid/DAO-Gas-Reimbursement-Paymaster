// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IReceiptNFT {
    function mintReceipt(address to, bytes32 userOpHash, uint256 actualGasCostWei, uint32 epochIndex) external returns (uint256 tokenId);
    function ownerOf(uint256 tokenId) external view returns (address);
}

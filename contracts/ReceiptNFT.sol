// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title ReceiptNFT - Soulbound receipts for sponsored UserOperations
/// @notice Non-transferable ERC-721 that implements ERC-5192 Locked behavior
contract ReceiptNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// ERC-5192: Locked event and interface
    event Locked(uint256 tokenId);

    struct ReceiptData {
        address sender;
        bytes32 userOpHash;
        uint256 actualGasCostWei;
        uint32 epochIndex;
        uint64 timestamp;
    }

    uint256 private _nextId = 1;
    mapping(uint256 => ReceiptData) private _receipts;

    constructor(address admin) ERC721("SponsoredReceipt", "RCPT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        // 0xb45a3c0e = ERC-5192 interface id
        return interfaceId == 0xb45a3c0e || ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    /// ERC-5192 locked(tokenId) is always true for existing tokens
    function locked(uint256 tokenId) external view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "!exist");
        return true;
    }

    // Enforce soulbound by allowing only mints (from == address(0)) in _update
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0)) revert("SBT");
        return super._update(to, tokenId, auth);
    }

    // Block setting approvals; allow clearing to zero
    function _approve(address to, uint256 tokenId, address auth, bool approvalCheck) internal override {
        if (to != address(0)) revert("SBT");
        super._approve(to, tokenId, auth, approvalCheck);
    }

    // Block operator approvals when setting true; allow clearing
    function _setApprovalForAll(address owner, address operator, bool approved) internal override {
        if (approved) revert("SBT");
        super._setApprovalForAll(owner, operator, approved);
    }

    function mintReceipt(
        address to,
        bytes32 userOpHash,
        uint256 actualGasCostWei,
        uint32 epochIndex
    ) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
        _receipts[tokenId] = ReceiptData({
            sender: to,
            userOpHash: userOpHash,
            actualGasCostWei: actualGasCostWei,
            epochIndex: epochIndex,
            timestamp: uint64(block.timestamp)
        });
        emit Locked(tokenId);
    }

    function getReceipt(uint256 tokenId) external view returns (ReceiptData memory) {
        return _receipts[tokenId];
    }
}

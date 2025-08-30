// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract GovActions {
    event ParamSet(bytes32 indexed key, uint256 value, address indexed caller);
    event RoleGranted(address indexed user, address indexed caller);

    mapping(bytes32 => uint256) public params;
    mapping(address => bool) public hasRole;

    function setParam(bytes32 key, uint256 value) external {
        params[key] = value;
        emit ParamSet(key, value, msg.sender);
    }

    function grantRole(address user) external {
        hasRole[user] = true;
        emit RoleGranted(user, msg.sender);
    }
}

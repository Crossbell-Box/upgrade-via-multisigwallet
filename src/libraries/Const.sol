// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library Const {
    string public constant STATUS_PENDING = "Pending";
    string public constant STATUS_DELETED = "Deleted";
    string public constant STATUS_EXECUTED = "Executed";

    address public constant SENTINEL_OWNER = address(0x1);

    string public constant TYPE_UPGRADE = "Upgrade";
    string public constant TYPE_UPGRADE_AND_CALL = "UpgradeToAndCall";
    string public constant CHANGE_ADMIN = "ChangeAdmin";
}

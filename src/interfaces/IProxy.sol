// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IProxy {
    function changeAdmin(address) external;

    function upgradeTo(address) external;

    function upgradeToAndCall(address, bytes memory) external payable;
}

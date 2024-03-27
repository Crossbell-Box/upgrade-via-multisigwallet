// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import "./UpgradeV1.sol";

contract UpgradeV2 is UpgradeV1 {
    // Increments the stored value by 1
    function increment() public {
        store(retrieve() + 1);
    }
}

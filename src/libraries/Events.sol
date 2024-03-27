// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Events {
    // events
    event Setup(address indexed initiator, address[] owners, uint256 indexed ownerCount, uint256 indexed threshold);

    event Proposed(
        uint256 indexed proposalId,
        address indexed proxy,
        string indexed proposalType, // "ChangeAdmin" or "Upgrade" or "UpgradeToAndCall"
        address newAdminOrImplementation,
        bytes data
    );
    event Approved(address indexed owner, uint256 indexed proposalId);
    event Deleted(address indexed owner, uint256 indexed proposalId);

    event Upgraded(address proxy, address newImplementation, bytes data);
    event AdminChanged(address proxy, address newAdmin);
}

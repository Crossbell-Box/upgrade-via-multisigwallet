// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IErrors {
    error NotOwner();
    error ThresholdIsZero();
    error ThresholdExceedsOwnersCount(uint256 threshold, uint256 ownersCount);
    error DuplicatedOwner(address owner);
    error ZeroAddress();
    error OwnerExists();
    error UnexpectedProposalType();
    error NotPendingProposal();
    error AlreadyApproved();
    error NotEnoughApproval();
}

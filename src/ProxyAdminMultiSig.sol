// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {IErrors} from "./interfaces/IErrors.sol";
import {Const} from "./libraries/Const.sol";
import {Events} from "./libraries/Events.sol";
import {IProxy} from "./interfaces/IProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ProxyAdminMultiSig is IErrors {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct Proposal {
        uint256 proposalId;
        string proposalType; // "ChangeAdmin" or "Upgrade" or "UpgradeToAndCall"
        address proxy;
        address newAdminOrImplementation;
        bytes data;
        uint256 approvalCount;
        address[] approvals;
        string status;
    }

    // multi-sig wallet
    EnumerableSet.AddressSet internal _owners;
    uint256 internal _threshold;

    // proposals
    uint256 internal _proposalCount;
    mapping(uint256 => Proposal) internal _proposals;
    EnumerableSet.UintSet internal _pendingProposalIds;

    modifier onlyOwner() {
        if (!_owners.contains(msg.sender)) {
            revert NotOwner();
        }
        _;
    }

    /// @dev constructor
    constructor(address[] memory owners, uint256 threshold) {
        if (threshold == 0) {
            revert ThresholdIsZero();
        }

        // initialize owners
        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            if (owner == address(0)) {
                revert ZeroAddress();
            }
            if (!_owners.add(owner)) {
                revert DuplicatedOwner(owner);
            }
        }
       uint256 ownersCount = _owners.length();
        _threshold = threshold;
        if (threshold > ownersCount) {
            revert ThresholdExceedsOwnersCount(threshold, ownersCount);
        }

        emit Events.Setup(msg.sender, owners, ownersCount, threshold);
    }

    /// @dev proposes a new admin or implementation for a proxy
    function propose(
        address proxy,
        string calldata proposalType,
        address newAdminOrImplementation,
        bytes calldata data
    ) external onlyOwner returns (uint256 proposalId) {
        if (
            !(_equal(proposalType, Const.TYPE_UPGRADE) ||
                _equal(proposalType, Const.TYPE_UPGRADE_AND_CALL) ||
                _equal(proposalType, Const.CHANGE_ADMIN))
        ) revert UnexpectedProposalType();

        proposalId = ++_proposalCount;
        // create proposal
        _proposals[proposalId].proposalId = proposalId;
        _proposals[proposalId].proxy = proxy;
        _proposals[proposalId].proposalType = proposalType;
        _proposals[proposalId].newAdminOrImplementation = newAdminOrImplementation;
        _proposals[proposalId].data = data;
        _proposals[proposalId].approvalCount = 0;
        _proposals[proposalId].status = Const.STATUS_PENDING;
        _pendingProposalIds.add(proposalId);

        emit Events.Proposed(proposalId, proxy, proposalType, newAdminOrImplementation, data);
    }

    /// @dev approves a pending proposal
    function approveProposal(uint256 proposalId) external onlyOwner {
        if (!_isPendingProposal(proposalId)) {
            revert NotPendingProposal();
        }
        if (_hasApproved(msg.sender, proposalId)) {
            revert AlreadyApproved();
        }

        // approve proposal
        _proposals[proposalId].approvalCount++;
        _proposals[proposalId].approvals.push(msg.sender);

        emit Events.Approved(msg.sender, proposalId);
    }

    /// @dev executes a proposal
    function executeProposal(uint256 proposalId) external onlyOwner {
        if (!_isPendingProposal(proposalId)) {
            revert NotPendingProposal();
        }

        Proposal storage p = _proposals[proposalId];
        if (p.approvalCount < _threshold) {
            revert NotEnoughApproval();
        }

        if (_equal(p.proposalType, Const.CHANGE_ADMIN)) {
            IProxy(p.proxy).changeAdmin(p.newAdminOrImplementation);
            emit Events.AdminChanged(p.proxy, p.newAdminOrImplementation);
        } else if (_equal(p.proposalType, Const.TYPE_UPGRADE)) {
            IProxy(p.proxy).upgradeTo(p.newAdminOrImplementation);
            emit Events.Upgraded(p.proxy, p.newAdminOrImplementation, "");
        } else if (_equal(p.proposalType, Const.TYPE_UPGRADE_AND_CALL)) {
            IProxy(p.proxy).upgradeToAndCall(p.newAdminOrImplementation, p.data);
            emit Events.Upgraded(p.proxy, p.newAdminOrImplementation, p.data);
        } else {
            revert("Unexpected proposal type");
        }

        // update proposal
        _pendingProposalIds.remove(proposalId);
        _proposals[proposalId].status = Const.STATUS_EXECUTED;
    }

    /// @dev rejects and delete a pending proposal
    function deleteProposal(uint256 proposalId) external onlyOwner {
        if (!_isPendingProposal(proposalId)) {
            revert NotPendingProposal();
        }

        _pendingProposalIds.remove(proposalId);
        _proposals[proposalId].status = Const.STATUS_DELETED;

        emit Events.Deleted(msg.sender, proposalId);
    }

    /// @dev returns pending proposals
    function getPendingProposals() external view returns (Proposal[] memory results) {
        uint256 len = _pendingProposalIds.length();

        results = new Proposal[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 pid = _pendingProposalIds.at(i);
            results[i] = _proposals[pid];
        }
    }

    /// @dev returns a proposal
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    /// @dev returns the threshold of multi-sig wallet
    function getThreshold() external view returns (uint256) {
        return _threshold;
    }

    /// @dev returns the owners of multi-sig wallet
    function getOwners() external view returns (address[] memory) {
        return _owners.values();
    }

    /// @dev get proposal count
    function getProposalCount() external view returns (uint256) {
        return _proposalCount;
    }

    /// @dev checks if an address is an owner
    function isOwner(address owner) external view returns (bool) {
        return _owners.contains(owner);
    }

    /// @dev checks if an owner has approved a proposal
    function _hasApproved(address owner, uint256 proposalId) internal view returns (bool) {
        // find the index of the owner in the approvals array, here we use MAX_UINT256 as a sentinel value
        uint256 index = type(uint256).max;
        address[] memory approvals = _proposals[proposalId].approvals;
        for (uint256 i = 0; i < approvals.length; i++) {
            if (owner == approvals[i]) {
                index = i;
                break;
            }
        }
        // if index not equal to MAX_UINT256, it means the owner has approved the proposal
        return index != type(uint256).max;
    }

    /// @dev checks if a proposal is pending
    function _isPendingProposal(uint256 proposalId) internal view returns (bool) {
        return _pendingProposalIds.contains(proposalId);
    }

    /// @dev returns true if the two strings are equal.
    function _equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

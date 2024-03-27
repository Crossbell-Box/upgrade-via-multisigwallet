// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {IErrors} from "./interfaces/IErrors.sol";
import {Const} from "./libraries/Const.sol";
import {Events} from "./libraries/Events.sol";
import {IProxy} from "./interfaces/IProxy.sol";

contract ProxyAdminMultiSig is IErrors {
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
    mapping(address => address) internal _owners;
    uint256 internal _ownersCount;
    uint256 internal _threshold;

    // proposals
    uint256 internal _proposalCount;
    mapping(uint256 => Proposal) internal _proposals;
    uint256[] internal _pendingProposalIds;

    modifier onlyOwner() {
        if (_owners[msg.sender] == address(0)) {
            revert NotOwner();
        }
        _;
    }

    /// @dev constructor
    constructor(address[] memory owners, uint256 threshold) {
        if (threshold == 0) {
            revert ThresholdIsZero();
        }
        if (threshold > owners.length) {
            revert ThresholdExceedsOwnersCount(threshold, owners.length);
        }

        // initialize owners
        address currentOwner = Const.SENTINEL_OWNER;
        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            if (owner == address(0) || owner == Const.SENTINEL_OWNER || currentOwner == owner) {
                revert InvalidOwner();
            }
            if (_owners[owner] != address(0)) {
                revert OwnerExists();
            }
            _owners[currentOwner] = owner;
            currentOwner = owner;
        }
        _owners[currentOwner] = Const.SENTINEL_OWNER;
        _ownersCount = owners.length;
        _threshold = threshold;

        emit Events.Setup(msg.sender, owners, _ownersCount, threshold);
    }

    /// @dev propose a new admin or implementation for a proxy
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
        _pendingProposalIds.push(proposalId);

        emit Events.Proposed(proposalId, proxy, proposalType, newAdminOrImplementation, data);
    }

    /// @dev approve a pending proposal
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

    /// @dev execute a proposal
    function executeProposal(uint256 proposalId) external onlyOwner {
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
        _deletePendingProposalId(proposalId);
        _proposals[proposalId].status = Const.STATUS_EXECUTED;
    }

    /// @dev reject and delete a pending proposal
    function deleteProposal(uint256 proposalId) external onlyOwner {
        if (!_isPendingProposal(proposalId)) {
            revert NotPendingProposal();
        }

        _deletePendingProposalId(proposalId);
        _proposals[proposalId].status = Const.STATUS_DELETED;

        emit Events.Deleted(msg.sender, proposalId);
    }

    /// @dev get pending proposals
    function getPendingProposals() external view returns (Proposal[] memory results) {
        uint256 len = _pendingProposalIds.length;

        results = new Proposal[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 pid = _pendingProposalIds[i];
            results[i] = _proposals[pid];
        }
    }

    /// @dev get all proposals
    function getAllProposals(uint256 offset, uint256 limit) external view returns (Proposal[] memory results) {
        if (offset >= _proposalCount) return results;

        uint256 len = _min(limit, _proposalCount - offset);

        results = new Proposal[](len);
        for (uint256 i = offset; i < offset + len; i++) {
            // plus 1 because proposalId starts from 1
            results[i - offset] = _proposals[i + 1];
        }
    }

    /// @dev get wallet detail
    function getWalletDetail() external view returns (uint256 threshold, uint256 ownersCount, address[] memory owners) {
        threshold = _threshold;
        ownersCount = _ownersCount;
        owners = _getOwners();
    }

    /// @dev get proposal count
    function getProposalCount() external view returns (uint256) {
        return _proposalCount;
    }

    /// @dev check if an address is an owner
    function isOwner(address owner) external view returns (bool) {
        return owner != Const.SENTINEL_OWNER && _owners[owner] != address(0);
    }

    function _deletePendingProposalId(uint256 proposalId) internal {
        // find index to be deleted
        uint256 valueIndex = 0;
        for (uint256 i = 0; i < _pendingProposalIds.length; i++) {
            if (proposalId == _pendingProposalIds[i]) {
                // plus 1 because index 0
                // means a value is not in the array.
                valueIndex = i + 1;
                break;
            }
        }

        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = _pendingProposalIds.length - 1;
            if (lastIndex != toDeleteIndex) {
                _pendingProposalIds[toDeleteIndex] = _pendingProposalIds[lastIndex];
            }

            // delete the slot
            _pendingProposalIds.pop();
        }
    }

    function _getOwners() internal view returns (address[] memory) {
        address[] memory array = new address[](_ownersCount);

        uint256 index = 0;
        address currentOwner = _owners[Const.SENTINEL_OWNER];
        while (currentOwner != Const.SENTINEL_OWNER) {
            array[index] = currentOwner;
            currentOwner = _owners[currentOwner];
            index++;
        }
        return array;
    }

    function _hasApproved(address owner, uint256 proposalId) internal view returns (bool) {
        uint256 valueIndex;
        Proposal memory proposal = _proposals[proposalId];
        for (uint256 i = 0; i < proposal.approvals.length; i++) {
            if (owner == proposal.approvals[i]) {
                // plus 1 because index 0
                // means a value is not in the array.
                valueIndex = i + 1;
                break;
            }
        }
        return valueIndex != 0;
    }

    function _isPendingProposal(uint256 proposalId) internal view returns (bool) {
        uint256 valueIndex;
        for (uint256 i = 0; i < _pendingProposalIds.length; i++) {
            if (proposalId == _pendingProposalIds[i]) {
                // plus 1 because index 0
                // means a value is not in the array.
                valueIndex = i + 1;
                break;
            }
        }

        return valueIndex != 0;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function _equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

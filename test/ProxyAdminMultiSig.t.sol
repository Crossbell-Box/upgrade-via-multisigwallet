// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {TransparentUpgradeableProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";
import {ProxyAdminMultiSig} from "../src/ProxyAdminMultiSig.sol";
import {UpgradeV1} from "../src/mocks/UpgradeV1.sol";
import {UpgradeV2} from "../src/mocks/UpgradeV2.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {Events} from "../src/libraries/Events.sol";
import {Const} from "../src/libraries/Const.sol";
import {Utils} from "./helpers/utils.sol";
import {Test} from "forge-std/Test.sol";

contract MultiSigTest is IErrors, Test, Utils {
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    address public dan = address(0x4444);
    address[] public ownersArr2 = [alice, bob];
    address[] public ownersArr3 = [alice, bob, charlie];
    address[] public replicatedOwners = [alice, alice];
    address[] public zeroOwners = [alice, address(0x0)];
    address[] public sentinelOwners = [alice, address(0x1)];
    address[] public existsOwners = [alice, bob, alice];

    ProxyAdminMultiSig public multiSig;
    address public implementationV1;
    address public implementationV2;

    address public proxy;

    function setUp() public {
        UpgradeV1 v1 = new UpgradeV1();
        implementationV1 = address(v1);

        UpgradeV1 v2 = new UpgradeV2();
        implementationV2 = address(v2);

        multiSig = new ProxyAdminMultiSig(ownersArr3, 2);
        TransparentUpgradeableProxy transparentProxy = new TransparentUpgradeableProxy(
            address(implementationV1),
            address(multiSig),
            abi.encodeWithSelector(UpgradeV1.initialize.selector, 1)
        );

        proxy = address(transparentProxy);
    }

    function testConstruct() public {
        multiSig = new ProxyAdminMultiSig(ownersArr3, 2);
        _checkWalletDetail(2, 3, ownersArr3);

        multiSig = new ProxyAdminMultiSig(ownersArr3, 3);
        _checkWalletDetail(3, 3, ownersArr3);

        multiSig = new ProxyAdminMultiSig(ownersArr2, 1);
        _checkWalletDetail(1, 2, ownersArr2);

        multiSig = new ProxyAdminMultiSig(ownersArr2, 2);
        _checkWalletDetail(2, 2, ownersArr2);
    }

    function testConstructFail() public {
        // Threshold can't be 0
        vm.expectRevert(ThresholdIsZero.selector);
        multiSig = new ProxyAdminMultiSig(ownersArr3, 0);

        // Threshold can't Exceed OwnersCount
        vm.expectRevert(abi.encodeWithSelector(ThresholdExceedsOwnersCount.selector, 4, 3));
        multiSig = new ProxyAdminMultiSig(ownersArr3, 4);

        // [alice, bob, alice] and [alice, alice, bob]
        // replicated owners
        vm.expectRevert(InvalidOwner.selector);
        multiSig = new ProxyAdminMultiSig(replicatedOwners, 1);

        // owner can't be 0x0 or 0x1
        vm.expectRevert(InvalidOwner.selector);
        multiSig = new ProxyAdminMultiSig(zeroOwners, 1);

        vm.expectRevert(InvalidOwner.selector);
        multiSig = new ProxyAdminMultiSig(sentinelOwners, 1);

        vm.expectRevert(OwnerExists.selector);
        multiSig = new ProxyAdminMultiSig(existsOwners, 1);
    }

    function testProposeToUpgrade() public {
        // alice propose to upgrade
        expectEmit();
        emit Events.Proposed(1, proxy, Const.TYPE_UPGRADE, implementationV2, "");
        vm.prank(alice);
        multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");

        // check proposal status
        _checkPendingProposal(
            1,
            proxy,
            Const.TYPE_UPGRADE,
            implementationV2,
            "",
            0,
            new address[](0),
            Const.STATUS_PENDING
        );
    }

    function testProposeToUpgradeFail() public {
        // case 1: not owner
        vm.expectRevert(NotOwner.selector);
        vm.prank(dan);
        multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");

        // case 2: invalid proposal type
        vm.expectRevert(UnexpectedProposalType.selector);
        vm.prank(alice);
        multiSig.propose(proxy, "upgrade", implementationV2, "");
    }

    function testProposeToUpgradeAndCall() public {
        bytes memory funSelector = abi.encodeWithSelector(UpgradeV2.increment.selector);

        // alice propose to upgrade and call
        expectEmit();
        emit Events.Proposed(1, proxy, Const.TYPE_UPGRADE_AND_CALL, implementationV2, funSelector);
        vm.prank(alice);
        multiSig.propose(proxy, Const.TYPE_UPGRADE_AND_CALL, implementationV2, funSelector);

        // check proposal status
        _checkPendingProposal(
            1,
            proxy,
            Const.TYPE_UPGRADE_AND_CALL,
            implementationV2,
            funSelector,
            0,
            new address[](0),
            Const.STATUS_PENDING
        );
    }

    function testProposeChangeAdmin() public {
        vm.prank(alice);
        multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");

        // check proposal status
        _checkPendingProposal(1, proxy, Const.CHANGE_ADMIN, dan, bytes(""), 0, new address[](0), Const.STATUS_PENDING);
        // check proposal count
        assertEq(multiSig.getProposalCount(), 1);
    }

    function testApproveProposalUpgrade() public {
        // alice propose to upgrade
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");

        expectEmit();
        emit Events.Approved(alice, proposalId);
        vm.prank(alice);
        multiSig.approveProposal(proposalId);

        expectEmit();
        emit Events.Approved(bob, proposalId);
        vm.prank(bob);
        multiSig.approveProposal(proposalId);

        expectEmit();
        emit Events.Approved(charlie, proposalId);
        vm.prank(charlie);
        multiSig.approveProposal(proposalId);

        _checkPendingProposal(
            proposalId,
            proxy,
            Const.TYPE_UPGRADE,
            implementationV2,
            bytes(""),
            3,
            array(alice, bob, charlie),
            Const.STATUS_PENDING
        );
    }

    function testApproveProposalUpgradeAndCall() public {
        bytes memory funSelector = abi.encodeWithSelector(UpgradeV2.increment.selector);

        // alice propose to upgrade
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.TYPE_UPGRADE_AND_CALL, implementationV2, funSelector);

        expectEmit();
        emit Events.Approved(alice, proposalId);
        vm.prank(alice);
        multiSig.approveProposal(proposalId);

        expectEmit();
        emit Events.Approved(bob, proposalId);
        vm.prank(bob);
        multiSig.approveProposal(proposalId);

        expectEmit();
        emit Events.Approved(charlie, proposalId);
        vm.prank(charlie);
        multiSig.approveProposal(proposalId);

        _checkPendingProposal(
            proposalId,
            proxy,
            Const.TYPE_UPGRADE_AND_CALL,
            implementationV2,
            funSelector,
            3,
            array(alice, bob, charlie),
            Const.STATUS_PENDING
        );
    }

    function testApproveProposalChangeAdmin() public {
        // alice propose to upgrade
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");

        expectEmit();
        emit Events.Approved(alice, proposalId);
        vm.prank(alice);
        multiSig.approveProposal(proposalId);

        expectEmit();
        emit Events.Approved(bob, proposalId);
        vm.prank(bob);
        multiSig.approveProposal(proposalId);

        expectEmit();
        emit Events.Approved(charlie, proposalId);
        vm.prank(charlie);
        multiSig.approveProposal(proposalId);

        _checkPendingProposal(
            proposalId,
            proxy,
            Const.CHANGE_ADMIN,
            dan,
            bytes(""),
            3,
            array(alice, bob, charlie),
            Const.STATUS_PENDING
        );
    }

    function testApproveProposalFail() public {
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");

        // case 1: not owner
        vm.expectRevert(NotOwner.selector);
        vm.prank(dan);
        multiSig.approveProposal(proposalId);

        // case 2: can't approve twice
        vm.startPrank(alice);
        multiSig.approveProposal(proposalId);
        vm.expectRevert(AlreadyApproved.selector);
        multiSig.approveProposal(proposalId);
        vm.stopPrank();

        // case 3: can't approve proposals that don't exist
        vm.startPrank(alice);
        vm.expectRevert(NotPendingProposal.selector);
        multiSig.approveProposal(0);
        vm.expectRevert(NotPendingProposal.selector);
        multiSig.approveProposal(2);
        vm.stopPrank();

        // case 4: can't approve proposal that's deleted
        vm.prank(bob);
        multiSig.deleteProposal(proposalId);
        vm.expectRevert(NotPendingProposal.selector);
        vm.prank(charlie);
        multiSig.approveProposal(proposalId);
    }

    function testDeleteProposal() public {
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");

        // check count
        assertEq(multiSig.getProposalCount(), 1);

        // delete proposal
        expectEmit();
        emit Events.Deleted(bob, proposalId);
        vm.prank(bob);
        multiSig.deleteProposal(proposalId);

        // check count after deleting
        // delete only remove the proposal id from pending list
        assertEq(multiSig.getProposalCount(), 1);

        // check proposal status
        _checkAllProposal(proposalId, proxy, Const.CHANGE_ADMIN, dan, "", 0, new address[](0), Const.STATUS_DELETED);
    }

    function testDeleteProposalFail() public {
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");
        assertEq(multiSig.getProposalCount(), 1);

        // case 1: not owner
        vm.prank(dan);
        vm.expectRevert(NotOwner.selector);
        multiSig.deleteProposal(proposalId);

        // case 2: proposal not exist
        vm.expectRevert(NotPendingProposal.selector);
        vm.prank(alice);
        multiSig.deleteProposal(2);

        // case 3: can't delete executed proposals
        // approve and execute proposal
        vm.prank(alice);
        multiSig.approveProposal(proposalId);
        vm.prank(bob);
        multiSig.approveProposal(proposalId);
        vm.prank(charlie);
        multiSig.executeProposal(proposalId);
        // try to delete proposal
        vm.expectRevert(NotPendingProposal.selector);
        vm.prank(alice);
        multiSig.deleteProposal(proposalId);
    }

    function testExecuteProposalUpgrade() public {
        // check initial implementation address
        assertEq(_getImplementation(proxy), address(implementationV1));

        // 1. propose
        // alice propose to upgrade
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");

        // 2. approve
        vm.prank(alice);
        multiSig.approveProposal(proposalId);

        vm.prank(bob);
        multiSig.approveProposal(proposalId);

        // check all proposal
        _checkPendingProposal(
            proposalId,
            proxy,
            Const.TYPE_UPGRADE,
            implementationV2,
            "",
            2,
            array(alice, bob),
            Const.STATUS_PENDING
        );

        // once there are enough approvals, execute automatically
        expectEmit();
        emit Events.Upgraded(proxy, implementationV2, "");
        vm.prank(charlie);
        multiSig.executeProposal(proposalId);

        assertEq(_getImplementation(proxy), implementationV2);
        _checkAllProposal(
            proposalId,
            proxy,
            Const.TYPE_UPGRADE,
            implementationV2,
            "",
            2,
            array(alice, bob),
            Const.STATUS_EXECUTED
        );
    }

    function testExecuteProposalUpgradeAndCall() public {
        bytes memory funSelector = abi.encodeWithSelector(UpgradeV2.increment.selector);

        // check initial implementation address
        assertEq(_getImplementation(proxy), address(implementationV1));

        // 1. propose
        // alice propose to upgrade
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.TYPE_UPGRADE_AND_CALL, implementationV2, funSelector);

        // 2. approve
        vm.prank(alice);
        multiSig.approveProposal(proposalId);

        vm.prank(bob);
        multiSig.approveProposal(proposalId);

        // check all proposal
        _checkPendingProposal(
            proposalId,
            proxy,
            Const.TYPE_UPGRADE_AND_CALL,
            implementationV2,
            funSelector,
            2,
            array(alice, bob),
            Const.STATUS_PENDING
        );

        // once there are enough approvals, execute automatically
        expectEmit();
        emit Events.Upgraded(proxy, implementationV2, funSelector);
        vm.prank(charlie);
        multiSig.executeProposal(proposalId);

        assertEq(_getImplementation(proxy), implementationV2);
        _checkAllProposal(
            proposalId,
            proxy,
            Const.TYPE_UPGRADE_AND_CALL,
            implementationV2,
            funSelector,
            2,
            array(alice, bob),
            Const.STATUS_EXECUTED
        );
        assertEq(UpgradeV2(proxy).retrieve(), 2);
    }

    function testExecuteProposalChangeAdmin() public {
        // 1. alice propose to change admin in to alice
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");

        assertEq(multiSig.getProposalCount(), 1);

        // 2. alice and bob approve
        vm.prank(alice);
        multiSig.approveProposal(proposalId);
        vm.prank(bob);
        multiSig.approveProposal(proposalId);

        // 3. execute proposal
        expectEmit();
        emit Events.AdminChanged(proxy, dan);
        vm.prank(charlie);
        multiSig.executeProposal(proposalId);

        // check the admin has changed
        assertEq(_getAdmin(proxy), dan);
        assertEq(_getImplementation(proxy), implementationV1);
        _checkAllProposal(proposalId, proxy, Const.CHANGE_ADMIN, dan, "", 2, array(alice, bob), Const.STATUS_EXECUTED);
    }

    function testExecuteMultipleProposals() public {
        // alice proposal to upgrade(proposalId=1)
        vm.prank(alice);
        multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");

        // bob propose to change admin(proposalId=2)
        vm.prank(bob);
        multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");

        // alice approve 1 and 2
        vm.startPrank(alice);
        multiSig.approveProposal(1);
        multiSig.approveProposal(2);
        vm.stopPrank();

        // charlie approve 1 and 2
        vm.startPrank(charlie);
        multiSig.approveProposal(1);
        multiSig.approveProposal(2);
        vm.stopPrank();

        // execute proposals
        vm.startPrank(bob);
        multiSig.executeProposal(1);
        multiSig.executeProposal(2);
        vm.stopPrank();

        // check executed status
        assertEq(_getImplementation(proxy), implementationV2);
        assertEq(_getAdmin(proxy), dan);
        _checkAllProposal(
            1,
            proxy,
            Const.TYPE_UPGRADE,
            implementationV2,
            "",
            2,
            array(alice, charlie),
            Const.STATUS_EXECUTED
        );
        _checkAllProposal(2, proxy, Const.CHANGE_ADMIN, dan, "", 2, array(alice, charlie), Const.STATUS_EXECUTED);
    }

    function testExecuteProposalFail() public {
        vm.prank(alice);
        uint256 proposalId = multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");

        // case 1: not owners
        vm.expectRevert(NotOwner.selector);
        multiSig.executeProposal(proposalId);
    }

    function testGetAllProposals() public {
        vm.prank(alice);
        multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");
        vm.prank(bob);
        multiSig.propose(proxy, Const.CHANGE_ADMIN, dan, "");
        vm.prank(charlie);
        multiSig.propose(
            proxy,
            Const.TYPE_UPGRADE_AND_CALL,
            implementationV2,
            abi.encodeWithSelector(UpgradeV2.increment.selector)
        );

        ProxyAdminMultiSig.Proposal[] memory proposals = multiSig.getAllProposals(0, 100);
        assertEq(proposals.length, 3);
        assertEq(multiSig.getAllProposals(0, 3).length, 3);
        assertEq(multiSig.getAllProposals(1, 1).length, 1);
        assertEq(multiSig.getAllProposals(1, 100).length, 2);

        vm.prank(alice);
        multiSig.approveProposal(1);
        vm.prank(bob);
        multiSig.approveProposal(1);
        assertEq(multiSig.getAllProposals(0, 100).length, 3);

        vm.prank(alice);
        multiSig.deleteProposal(3);

        vm.prank(alice);
        multiSig.deleteProposal(2);
        assertEq(multiSig.getAllProposals(0, 100).length, 3);
    }

    function testGetAllProposalsFail() public {
        // offset >= proposalCount returns nothing
        ProxyAdminMultiSig.Proposal[] memory proposals = multiSig.getAllProposals(2, 2);
        assertEq(proposals.length, 0);
    }

    function testGetPendingProposals() public {
        assertEq(multiSig.getPendingProposals().length, 0);

        vm.prank(alice);
        multiSig.propose(proxy, Const.TYPE_UPGRADE, implementationV2, "");
        vm.prank(bob);
        multiSig.propose(proxy, Const.CHANGE_ADMIN, address(bob), "");
        assertEq(multiSig.getPendingProposals().length, 2);

        vm.prank(alice);
        multiSig.approveProposal(1);
        vm.prank(bob);
        multiSig.approveProposal(1);
        vm.prank(charlie);
        multiSig.executeProposal(1);
        assertEq(multiSig.getPendingProposals().length, 1);

        vm.prank(alice);
        multiSig.deleteProposal(2);
        assertEq(multiSig.getPendingProposals().length, 0);
    }

    // checkPendingProposal checks if a Pending Proposal is in Pending list and its information
    function _checkPendingProposal(
        uint256 proposalId,
        address proxy_,
        string memory proposalType,
        address newAdminOrImplementation,
        bytes memory data,
        uint256 approvalCount,
        address[] memory approvals,
        string memory status
    ) internal {
        // get pending proposals and all proposals
        ProxyAdminMultiSig.Proposal[] memory pendingProposals = multiSig.getPendingProposals();
        ProxyAdminMultiSig.Proposal[] memory allProposals = multiSig.getAllProposals(proposalId - 1, 1);
        // get proposal by _proposalId
        ProxyAdminMultiSig.Proposal memory proposal = allProposals[proposalId - 1];
        // check if this id is in pending list
        bool exist = false;
        for (uint256 i = 0; i < pendingProposals.length; i++) {
            ProxyAdminMultiSig.Proposal memory thisProposal = pendingProposals[i];
            if (thisProposal.proposalId == proposalId) {
                exist = true;
            }
        }
        assert(exist);
        assertEq(proposal.proxy, proxy_);
        assertEq(proposal.proposalType, proposalType);
        assertEq(proposal.newAdminOrImplementation, newAdminOrImplementation);
        assertEq(keccak256(proposal.data), keccak256(data));
        assertEq(proposal.approvalCount, approvalCount);
        assertEq(proposal.approvals, approvals);
        assertEq(proposal.status, status);
    }

    function _checkAllProposal(
        uint256 proposalId,
        address proxy_,
        string memory proposalType,
        address adminOrImplementation,
        bytes memory data,
        uint256 approvalCount,
        address[] memory approvals,
        string memory status
    ) internal {
        ProxyAdminMultiSig.Proposal[] memory proposals = multiSig.getAllProposals(proposalId - 1, 1);
        ProxyAdminMultiSig.Proposal memory p = proposals[0];
        assertEq(p.proxy, proxy_);
        assertEq(p.proposalType, proposalType);
        assertEq(p.newAdminOrImplementation, adminOrImplementation);
        assertEq(keccak256(p.data), keccak256(data));
        assertEq(p.approvalCount, approvalCount);
        assertEq(p.approvals, approvals);
        assertEq(p.status, status);
    }

    function _checkWalletDetail(uint256 threshold_, uint256 ownersCount_, address[] memory owners_) internal {
        (uint256 threshold, uint256 ownersCount, address[] memory owners) = multiSig.getWalletDetail();
        assertEq(threshold, threshold_);
        assertEq(ownersCount, ownersCount_);
        assertEq(owners, owners_);
    }

    function _getImplementation(address proxy_) internal returns (address) {
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 impl = vm.load(proxy_, implementationSlot);
        return address(uint160(uint256(impl)));
    }

    function _getAdmin(address proxy_) internal returns (address) {
        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 admin = vm.load(proxy_, adminSlot);
        return address(uint160(uint256(admin)));
    }
}

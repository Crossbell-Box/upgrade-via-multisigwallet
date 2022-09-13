// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/ProxyAdminMultisig.sol";
import "../contracts/mocks/UpgradeV1.sol";
import "../contracts/mocks/UpgradeV2.sol";
import "./helpers/utils.sol";
import "../contracts/libraries/Constants.sol";

interface DumbEmitterEvents {
    // events
    event Setup(
        address indexed initiator,
        address[] owners,
        uint256 indexed ownerCount,
        uint256 indexed threshold
    );

    event Propose(
        uint256 indexed proposalId,
        address target,
        string proposalType, // Constants.PROPOSAL_TYPE_CHANGE_ADMIN or "Upgrade"
        address data
    );
    event Approval(address indexed owner, uint256 indexed proposalId);
    event Delete(address indexed owner, uint256 indexed proposalId);
    event Execution(
        uint256 indexed proposalId,
        address target,
        string proposalType, // Constants.PROPOSAL_TYPE_CHANGE_ADMIN or "Upgrade"
        address data
    );
    event Upgrade(address target, address implementation);
    event ChangeAdmin(address target, address newAdmin);
}

contract MultisigTest is DumbEmitterEvents, Test, Utils {
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    address public daniel = address(0x4444);
    address[] public ownersArr2 = [alice, bob];
    address[] public ownersArr3 = [alice, bob, charlie];
    address[] public replicatedOwners = [alice, alice];
    address[] public zeroOwners = [alice, address(0x0)];
    address[] public sentinelOwners = [alice, address(0x1)];
    address[] public existsOwners = [alice, bob, alice];

    ProxyAdminMultisig proxyAdminMultisig;
    TransparentUpgradeableProxy transparentUpgradeableProxy;
    UpgradeV1 upgradeV1;
    UpgradeV2 upgradeV2;

    address target;

    function setUp() public {
        upgradeV1 = new UpgradeV1();
        upgradeV2 = new UpgradeV2();
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr3, 2);
        transparentUpgradeableProxy = new TransparentUpgradeableProxy(
            address(upgradeV1),
            address(proxyAdminMultisig),
            abi.encodeWithSelector(upgradeV1.initialize.selector, 1)
        );

        target = address(transparentUpgradeableProxy);
    }

    function testConstruct() public {
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr3, 2);
        _checkWalletDetail(2, 3, ownersArr3);
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr3, 3);
        _checkWalletDetail(3, 3, ownersArr3);
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr2, 1);
        _checkWalletDetail(1, 2, ownersArr2);
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr2, 2);
        _checkWalletDetail(2, 2, ownersArr2);
    }

    function testConstructFail() public {
        // Threshold can't be 0
        vm.expectRevert(abi.encodePacked("ThresholdIsZero"));
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr3, 0);

        // Threshold can't Exceed OwnersCount
        vm.expectRevert(abi.encodePacked("ThresholdExceedsOwnersCount"));
        proxyAdminMultisig = new ProxyAdminMultisig(ownersArr3, 4);

        // [alice, bob, alice] and [alice, alice, bob]
        // replicated owners
        vm.expectRevert(abi.encodePacked("InvalidOwner"));
        proxyAdminMultisig = new ProxyAdminMultisig(replicatedOwners, 1);

        // owner can't be 0x0 or 0x1
        vm.expectRevert(abi.encodePacked("InvalidOwner"));
        proxyAdminMultisig = new ProxyAdminMultisig(zeroOwners, 1);
        vm.expectRevert(abi.encodePacked("InvalidOwner"));
        proxyAdminMultisig = new ProxyAdminMultisig(sentinelOwners, 1);
        vm.expectRevert(abi.encodePacked("OwnerExists"));
        proxyAdminMultisig = new ProxyAdminMultisig(existsOwners, 1);
    }

    function testProposeToUpgrade() public {
        // alice propose to upgrade
        expectEmit(CheckTopic1 | CheckTopic2 | CheckTopic3 | CheckData);
        vm.startPrank(alice);
        emit Propose(1, target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));

        // check proposal status
        _checkPendingProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_UPGRADE,
            address(upgradeV2),
            0,
            new address[](0),
            Constants.PROPOSAL_STATUS_PENDING
        );
    }

    function testProposeToUpgradeFail() public {
        // not owner can't propose
        vm.expectRevert(abi.encodePacked("NotOwner"));
        vm.prank(daniel);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));

        // can'e offer invalid proposal
        vm.expectRevert("Unexpected proposal type");
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));
    }

    function testProposeChangeAdmin() public {
        // 1. alice propose to change admin in to alice
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_CHANGE_ADMIN, address(alice));

        // check proposal status
        ProxyAdminMultisig.Proposal[] memory proposalsC1 = proxyAdminMultisig.getPendingProposals();
        _checkPendingProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_CHANGE_ADMIN,
            alice,
            0,
            new address[](0),
            Constants.PROPOSAL_STATUS_PENDING
        );
        // check proposal count
        assertEq(proxyAdminMultisig.getProposalCount(), 1);
    }

    function testApproveProposal() public {
        vm.startPrank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));
        proxyAdminMultisig.approveProposal(1);

        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_CHANGE_ADMIN, address(alice));
        proxyAdminMultisig.approveProposal(2);
    }

    function testApproveProposalFail() public {
        // not owner can't approve
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));
        vm.expectRevert(abi.encodePacked("NotOwner"));
        vm.prank(daniel);
        proxyAdminMultisig.approveProposal(1);

        // can't approve twice
        vm.startPrank(alice);
        proxyAdminMultisig.approveProposal(1);
        vm.expectRevert(abi.encodePacked("AlreadyApproved"));
        proxyAdminMultisig.approveProposal(1);
        vm.stopPrank();

        // can't approve proposals that don't exist
        vm.startPrank(alice);
        vm.expectRevert(abi.encodePacked("NotPendingProposal"));
        proxyAdminMultisig.approveProposal(0);
        vm.expectRevert(abi.encodePacked("NotPendingProposal"));
        proxyAdminMultisig.approveProposal(2);
        vm.stopPrank();

        // can't approve proposals that's deleted
        vm.prank(bob);
        proxyAdminMultisig.approveProposal(1);
        vm.expectRevert(abi.encodePacked("NotPendingProposal"));
        vm.startPrank(charlie);
        proxyAdminMultisig.approveProposal(1);
    }

    function testDeleteProposal() public {
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_CHANGE_ADMIN, address(alice));

        // check count
        assertEq(proxyAdminMultisig.getProposalCount(), 1);
        vm.prank(alice);
        proxyAdminMultisig.deleteProposal(1);

        // check count after deleting
        // delete only remove the proposal id from pending list
        assertEq(proxyAdminMultisig.getProposalCount(), 1);

        // check proposal status
        _checkAllProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_CHANGE_ADMIN,
            alice,
            0,
            new address[](0),
            Constants.PROPOSAL_STATUS_DELETED
        );
    }

    function testDeleteProposalFail() public {
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_CHANGE_ADMIN, address(alice));
        assertEq(proxyAdminMultisig.getProposalCount(), 1);

        vm.prank(daniel);
        vm.expectRevert(abi.encodePacked("NotOwner"));
        proxyAdminMultisig.deleteProposal(1);
        assertEq(proxyAdminMultisig.getProposalCount(), 1);

        vm.expectRevert(abi.encodePacked("NotPendingProposal"));
        vm.prank(alice);
        proxyAdminMultisig.deleteProposal(2);

        // can't delete executed proposals
        vm.prank(alice);
        proxyAdminMultisig.approveProposal(1);
        vm.prank(bob);
        proxyAdminMultisig.approveProposal(1);
        vm.expectRevert(abi.encodePacked("NotPendingProposal"));
        vm.prank(alice);
        proxyAdminMultisig.deleteProposal(1);
    }

    function testUpgrade() public {
        // check initial implementation address
        vm.prank(address(proxyAdminMultisig));
        address preImplementation = transparentUpgradeableProxy.implementation();
        assertEq(preImplementation, address(upgradeV1));

        // 1. propose
        // alice propose to upgrade
        expectEmit(CheckTopic1 | CheckTopic2 | CheckTopic3 | CheckData);
        vm.startPrank(alice);
        emit Propose(1, target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));

        // check proposal status
        _checkPendingProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_UPGRADE,
            address(upgradeV2),
            0,
            new address[](0),
            Constants.PROPOSAL_STATUS_PENDING
        );

        // 2. approve
        // alice approve the proposal
        expectEmit(CheckTopic1 | CheckTopic2 | CheckTopic3 | CheckData);
        emit Approval(alice, 1);
        proxyAdminMultisig.approveProposal(1);

        address[] memory approved = new address[](1);
        approved[0] = alice;
        _checkPendingProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_UPGRADE,
            address(upgradeV2),
            1,
            approved,
            Constants.PROPOSAL_STATUS_PENDING
        );
        vm.stopPrank();

        // shouldn't upgrade when there is not enough approval
        vm.prank(address(proxyAdminMultisig));
        assertEq(transparentUpgradeableProxy.implementation(), address(upgradeV1));
        // bob approve the proposal
        vm.startPrank(bob);
        // expect approve event
        expectEmit(CheckTopic1 | CheckTopic2 | CheckTopic3 | CheckData);
        emit Approval(bob, 1);
        // expect upgrade event
        expectEmit(CheckTopic1 | CheckTopic2 | CheckTopic3 | CheckData);
        emit Upgrade(target, address(upgradeV2));
        proxyAdminMultisig.approveProposal(1);
        // check all proposal
        _checkAllProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_UPGRADE,
            address(upgradeV2),
            2,
            ownersArr2,
            Constants.PROPOSAL_STATUS_EXECUTED
        );
        vm.stopPrank();

        // once there are enough approvals, execute automatically
        vm.prank(address(proxyAdminMultisig));
        assertEq(transparentUpgradeableProxy.implementation(), address(upgradeV2));
    }

    function testChangeAdmin() public {
        // 1. alice propose to change admin in to alice
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_CHANGE_ADMIN, address(alice));

        // check proposal status
        ProxyAdminMultisig.Proposal[] memory proposalsC1 = proxyAdminMultisig.getPendingProposals();
        _checkPendingProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_CHANGE_ADMIN,
            alice,
            0,
            new address[](0),
            Constants.PROPOSAL_STATUS_PENDING
        );
        // check proposal count
        assertEq(proxyAdminMultisig.getProposalCount(), 1);

        // 2. alice and bob approve
        vm.prank(alice);
        proxyAdminMultisig.approveProposal(1);
        // check proposal status
        address[] memory approved = new address[](1);
        approved[0] = alice;
        _checkPendingProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_CHANGE_ADMIN,
            alice,
            1,
            approved,
            Constants.PROPOSAL_STATUS_PENDING
        );
        // check proposal count
        assertEq(proxyAdminMultisig.getProposalCount(), 1);
        vm.prank(bob);
        proxyAdminMultisig.approveProposal(1);
        // check proposal status
        _checkAllProposal(
            1,
            target,
            Constants.PROPOSAL_TYPE_CHANGE_ADMIN,
            alice,
            2,
            ownersArr2,
            Constants.PROPOSAL_STATUS_EXECUTED
        );
        // check count
        uint256 countC3 = proxyAdminMultisig.getProposalCount();
        assertEq(countC3, 1);

        // check the admin has changed
        vm.prank(alice);
        assertEq(transparentUpgradeableProxy.admin(), alice);
    }

    function testMultipleProposals() public {
        // alice proposal to upgrade(proposalId=1)
        vm.prank(alice);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_UPGRADE, address(upgradeV2));

        // bob propose to change admin(proposalId=2)
        vm.prank(bob);
        proxyAdminMultisig.propose(target, Constants.PROPOSAL_TYPE_CHANGE_ADMIN, address(alice));

        // alice approve 1 and 2
        vm.startPrank(alice);
        proxyAdminMultisig.approveProposal(1);
        proxyAdminMultisig.approveProposal(2);
        vm.stopPrank();
        // charlie approve 1 and 2
        vm.startPrank(charlie);
        proxyAdminMultisig.approveProposal(1);
        proxyAdminMultisig.approveProposal(2);
        vm.stopPrank();

        // check executed status
        vm.prank(alice);
        assertEq(transparentUpgradeableProxy.implementation(), address(upgradeV2));
        vm.prank(alice);
        assertEq(transparentUpgradeableProxy.admin(), alice);
    }

    function testGetAllProposals() public {}

    function testGetPendingProposals() public {}

    function _checkPendingProposal(
        uint256 _proposalId,
        address _target,
        string memory _proposalType,
        address _data,
        uint256 _approvalCount,
        address[] memory _approvals,
        string memory _status
    ) internal {
        ProxyAdminMultisig.Proposal[] memory _proposals = proxyAdminMultisig.getPendingProposals();
        // TODO: search proposal by proposal id

        ProxyAdminMultisig.Proposal memory _proposal = _proposals[_proposalId - 1];
        assertEq(_proposal.target, _target);
        assertEq(_proposal.proposalType, _proposalType);
        assertEq(_proposal.data, _data);
        assertEq(_proposal.approvalCount, _approvalCount);
        assertEq(_proposal.approvals, _approvals);
        assertEq(_proposal.status, _status);
    }

    function _checkAllProposal(
        uint256 _proposalId,
        address _target,
        string memory _proposalType,
        address _data,
        uint256 _approvalCount,
        address[] memory _approvals,
        string memory _status
    ) internal {
        ProxyAdminMultisig.Proposal[] memory _proposals = proxyAdminMultisig.getAllProposals(
            _proposalId - 1,
            1
        );
        ProxyAdminMultisig.Proposal memory _proposal = _proposals[0];
        assertEq(_proposal.target, _target);
        assertEq(_proposal.proposalType, _proposalType);
        assertEq(_proposal.data, _data);
        assertEq(_proposal.approvalCount, _approvalCount);
        assertEq(_proposal.approvals, _approvals);
        assertEq(_proposal.status, _status);
    }

    function _checkWalletDetail(
        uint256 _threshold,
        uint256 _ownersCount,
        address[] memory _owners
    ) internal {
        uint256 threshold;
        uint256 ownersCount;
        address[] memory owners;
        (threshold, ownersCount, owners) = proxyAdminMultisig.getWalletDetail();
        assertEq(threshold, _threshold);
        assertEq(ownersCount, _ownersCount);
        assertEq(owners, _owners);
    }
}

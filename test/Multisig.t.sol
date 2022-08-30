// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Multisig.sol";
import "../src/ImplementationExample.sol";
import "../src/ImplementationExample2.sol";
import "../src/TransparentUpgradeableProxy.sol";

contract MultisigTest is Test {
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    address public daniel = address(0x4444);
    address[] public ownersArr =  [alice, bob, charlie, daniel];

    Multisig multisig;
    ImplementationExample implementationExample;
    ImplementationExample2 implementationExample2;
    TransparentUpgradeableProxy transparentUpgradeableProxy;

    function setUp() public {
        multisig = new Multisig(ownersArr, 3);
        implementationExample = new ImplementationExample();
        implementationExample2 = new ImplementationExample2();
        // admin of transparentUpgradeableProxy is set to multisig
        transparentUpgradeableProxy = new TransparentUpgradeableProxy(address(implementationExample), address(multisig), abi.encodeWithSelector(implementationExample.initialize.selector, 1));
    }

    function testProposeToUpgrade() public {
        // 1. alice propose to upgrade
        vm.prank(alice);
        multisig.propose(transparentUpgradeableProxy, false, address(implementationExample2));
        // 2. alice and bob approve the proposal
        vm.prank(alice);
        multisig.approveProposal(1, true);
        vm.prank(alice);
        multisig.executeProposal(1);
    }

    function testProposeToChangeAdmin() public {
        // 1. alice propose to change admin in to alice
        vm.startPrank(alice);
        multisig.propose(transparentUpgradeableProxy, true, address(alice));
        multisig.executeProposal(1);
        address admin = transparentUpgradeableProxy.admin();
        assertEq(admin, alice);
    }


    function testGetProposalCount() public {
        // owner can propose but others can't
        vm.expectRevert(abi.encodePacked("NotOwner"));
        vm.prank(daniel);
        multisig.propose(transparentUpgradeableProxy, false, address(implementationExample2));
        vm.prank(alice);
        multisig.propose(transparentUpgradeableProxy, false, address(implementationExample2));
        uint256 count = multisig.getProposalCount();
        assertEq(count, 1);
        multisig.getAllProposals(1, 1);
    }
}
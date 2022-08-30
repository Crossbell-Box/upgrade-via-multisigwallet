// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Multisig2.sol";

contract MultisigTest2 is Test {
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    address public daniel = address(0x4444);
    address[] public ownersArr = [alice, bob, charlie];

    Multisig2 multisig;

    struct Proposal {
        address to;
        uint256 amount;
        uint256 approvalCount;
        address[] approvals;
        string status;
    }

    Proposal[] proposals;

    function setUp() public {
        multisig = new Multisig2(ownersArr, 2);
    }

    function testMul() public {
        vm.deal(address(multisig), 10 ether);
        console.log(address(multisig).balance);
        // alice propose to transfer
        vm.prank(alice);
        multisig.proposeTransfer(bob, 1);
        // alice approve
        vm.prank(alice);
        multisig.approveProposal(1, true);
        // bob approve
        vm.prank(bob);
        multisig.approveProposal(1, true);
        // execute automatically if get enough approval
        console.log(bob.balance);
        console.log(address(multisig).balance);
    }

    function testMul2() public {
        vm.deal(address(multisig), 10 ether);
        console.log(address(multisig).balance);
        // alice propose to transfer
        vm.prank(alice);
        multisig.proposeTransfer(bob, 1);
        // alice approve
        vm.prank(alice);
        multisig.approveProposal(1, true);

        // alice execute
        vm.prank(alice);
        multisig.executeProposal(1);
        console.log(bob.balance);
        console.log(address(multisig).balance);
    }
}

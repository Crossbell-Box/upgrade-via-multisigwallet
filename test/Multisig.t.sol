// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Multisig.sol";

contract MultisigTest is Test {
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);

    address[] public ownersArr =  [alice, bob, charlie];

    Multisig multisig;

    function setUp() public {
        multisig = new Multisig(ownersArr, 2);
    }

    function testGetProposalCount() public view {
        uint256 count = multisig.getProposalCount();
        console.log(count);
    }
}
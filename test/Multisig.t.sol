// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Multisig.sol";
import "../src/ImplementationExample.sol";
import "../src/ImplementationExample2.sol";
import "../src/ProxyAdmin.sol";
import "../src/TransparentUpgradeableProxy.sol";

contract MultisigTest is Test {
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    address public daniel = address(0x4444);
    address[] public ownersArr =  [alice, bob, charlie];

    Multisig multisig;
    ImplementationExample implementationExample;
    ImplementationExample2 implementationExample2;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy transparentUpgradeableProxy;

    function setUp() public {
        multisig = new Multisig(ownersArr, 2);
        implementationExample = new ImplementationExample();
        implementationExample2 = new ImplementationExample2();
        proxyAdmin = new ProxyAdmin();
        transparentUpgradeableProxy = new TransparentUpgradeableProxy(address(implementationExample), address(proxyAdmin), abi.encodeWithSelector(implementationExample.initialize.selector, 1));
    }

    function testMultisigExecute() public {
        //! first, change admin of ProxyAdmin into multisig contract
        address preAdmin = proxyAdmin.getProxyAdmin(transparentUpgradeableProxy);
        assertEq(preAdmin, address(this));
        vm.prank(address(proxyAdmin));
        proxyAdmin.changeProxyAdmin(transparentUpgradeableProxy, address(alice));
        // vm.startPrank(address(multisig));
        // address postAdmin = proxyAdmin.getProxyAdmin(transparentUpgradeableProxy);
        // assertEq(postAdmin, address(multisig));

        // //! propose and execute
        // vm.prank(alice);
        // multisig.proposeUpgrade(transparentUpgradeableProxy, address(implementationExample2));

    }

    function testGetProposalCount() public {
        // owner can propose but others can't
        vm.expectRevert(abi.encodePacked("NotOwner"));
        vm.prank(daniel);
        multisig.proposeUpgrade(transparentUpgradeableProxy, address(implementationExample2));
        vm.prank(alice);
        multisig.proposeUpgrade(transparentUpgradeableProxy, address(implementationExample2));
        uint256 count = multisig.getProposalCount();
        assertEq(count, 1);
        multisig.getAllProposals(1, 1);
    }
}
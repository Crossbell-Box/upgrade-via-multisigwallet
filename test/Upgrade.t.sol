// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/ImplementationExample.sol";
import "../src/ImplementationExample2.sol";
import "../src/ProxyAdmin.sol";
import "../src/TransparentUpgradeableProxy.sol";

contract UpgradeTest is Test {
    address public alice = address(0x1111);

    ImplementationExample implementationExample;
    ImplementationExample2 implementationExample2;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy transparentUpgradeableProxy;

    function setUp() public {
        implementationExample = new ImplementationExample();
        implementationExample2 = new ImplementationExample2();
        proxyAdmin = new ProxyAdmin();
        // check here:https://www.notion.so/practice-transparent-upgradeable-contract-5216c5f5737f49fbbfab7a5469adbe40
        // the third para is the calldata when calling initialize func
        //! how to get 0xfe4b84df?
        // cast sig "initialize(uint256 _initialValue)"
        // transparentUpgradeableProxy = new TransparentUpgradeableProxy(address(implementationExample), address(proxyAdmin), abi.encodeWithSelector(0xfe4b84df,1));
        // ! or in a better way: using funcxxx.selector
        transparentUpgradeableProxy = new TransparentUpgradeableProxy(
            address(implementationExample),
            address(proxyAdmin),
            abi.encodeWithSelector(implementationExample.initialize.selector, 1)
        );
    }

    function testGetInformation() public {
        // get admin (when msg.sender is owner)
        address admin = proxyAdmin.getProxyAdmin(transparentUpgradeableProxy);
        assertEq(admin, address(proxyAdmin));
        // get implementation address
        address implement = proxyAdmin.getProxyImplementation(transparentUpgradeableProxy);
        assertEq(implement, address(implementationExample));
    }

    function testAdminCan() public {
        // admin can upgrade but others can't
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        vm.prank(alice);
        proxyAdmin.upgrade(transparentUpgradeableProxy, address(implementationExample2));
        vm.stopPrank();
        proxyAdmin.upgrade(transparentUpgradeableProxy, address(implementationExample2));

        // admin can change admin but others can't
        // ! usually you don't need to change this admin
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        vm.prank(alice);
        proxyAdmin.changeProxyAdmin(transparentUpgradeableProxy, alice);
        vm.stopPrank();
        proxyAdmin.changeProxyAdmin(transparentUpgradeableProxy, alice);
    }

    function testProxy() public {
        //! how to call retrive() via proxy?
        // the initial value is 1
        // TODO
    }

    function testAliceIsOwnerOfProxyAdmin() public {
        proxyAdmin.transferOwnership(alice);
        vm.startPrank(alice);
        proxyAdmin.upgrade(transparentUpgradeableProxy, address(implementationExample2));
    }
}

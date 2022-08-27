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
        transparentUpgradeableProxy = new TransparentUpgradeableProxy(address(implementationExample),address(proxyAdmin), abi.encodeWithSelector(0xfe4b84df,1));
    }

    function testGetAdmin() public {
        address admin = proxyAdmin.getProxyAdmin(transparentUpgradeableProxy);
        assertEq(admin, address(proxyAdmin));
    }

    function testGetProxyImplementation() public {
        address implement = proxyAdmin.getProxyImplementation(transparentUpgradeableProxy);
        assertEq(implement, address(implementationExample));
    }

    function testUpgrade() public {
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        vm.prank(alice);
        proxyAdmin.upgrade(transparentUpgradeableProxy, address(implementationExample2));
        
        vm.stopPrank();
        proxyAdmin.upgrade(transparentUpgradeableProxy, address(implementationExample2));
    }

}
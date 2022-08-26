// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/ImplementationExample.sol";
import "../src/ProxyAdmin.sol";
import "../src/TransparentUpgradeableProxy.sol";

contract UpgradeTest is Test {
    ImplementationExample implementationExample;
    ProxyAdmin proxyAdmin;
    TransparentUpgradeableProxy transparentUpgradeableProxy;

    function setUp() public {
        implementationExample = new ImplementationExample();
        proxyAdmin = new ProxyAdmin();
        transparentUpgradeableProxy = new TransparentUpgradeableProxy(address(implementationExample),address(proxyAdmin),new bytes(0));
    }

    function testGetAdmin() public {
        address admin = proxyAdmin.getProxyAdmin(transparentUpgradeableProxy);
        assertEq(admin, address(proxyAdmin));
    }

    function testGetProxyImplementation() public {
        address implement = proxyAdmin.getProxyImplementation(transparentUpgradeableProxy);
        assertEq(implement, address(implementationExample));
    }

}
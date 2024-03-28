// SPDX-License-Identifier: MIT
// solhint-disable no-console,ordering
pragma solidity 0.8.20;

import {Deployer} from "./Deployer.sol";
import {DeployConfig} from "./DeployConfig.s.sol";
import {ProxyAdminMultiSig} from "../src/ProxyAdminMultiSig.sol";
import {console2 as console} from "forge-std/console2.sol";

contract Deploy is Deployer {
    // solhint-disable private-vars-leading-underscore
    DeployConfig internal cfg;

    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    /// @notice The name of the script, used to ensure the right deploy artifacts
    ///         are used.
    function name() public pure override returns (string memory name_) {
        name_ = "Deploy";
    }

    function setUp() public override {
        super.setUp();
        string memory path = string.concat(vm.projectRoot(), "/deploy-config/", deploymentContext, ".json");
        cfg = new DeployConfig(path);

        console.log("Deploying from %s", deployScript);
        console.log("Deployment context: %s", deploymentContext);
    }

    /* solhint-disable comprehensive-interface */
    function run() external {
        deployProxyAdminMultiSig();
    }

    function deployProxyAdminMultiSig() public broadcast returns (address addr_) {
        ProxyAdminMultiSig multiSig = new ProxyAdminMultiSig(cfg.getOwners(), cfg.getThreshold());

        // check states
        require(multiSig.getThreshold() == cfg.getThreshold(), "Threshold mismatch");
        address[] memory owners = multiSig.getOwners();
        for (uint256 i = 0; i < owners.length; i++) {
            require(multiSig.isOwner(owners[i]), "Owners mismatch");
        }

        save("ProxyAdminMultiSig", address(multiSig));
        console.log("ProxyAdminMultiSig deployed at %s", address(multiSig));
        addr_ = address(multiSig);
    }
}

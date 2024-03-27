// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,no-console
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

/// @title DeployConfig
/// @notice Represents the configuration required to deploy the system. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract DeployConfig is Script {
    string internal _json;

    struct OwnersConfig {
        address[] owners;
        uint256 threshold;
    }

    OwnersConfig internal _config;

    constructor(string memory _path) {
        console.log("DeployConfig: reading file %s", _path);
        try vm.readFile(_path) returns (string memory data) {
            _json = data;
        } catch {
            console.log("Warning: unable to read config. Do not deploy unless you are not using config.");
            return;
        }

        _config.owners = stdJson.readAddressArray(_json, "$.owners");
        _config.threshold = stdJson.readUint(_json, "$.threshold");
    }

    function getOwners() public view returns (address[] memory) {
        return _config.owners;
    }

    function getThreshold() public view returns (uint256) {
        return _config.threshold;
    }
}

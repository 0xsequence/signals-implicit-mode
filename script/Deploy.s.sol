// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import { SingletonDeployer, console } from "erc2470-libs/script/SingletonDeployer.s.sol";
import { ImplicitProjectRegistry } from "src/registry/ImplicitProjectRegistry.sol";

contract Deploy is SingletonDeployer {

  function run() external {
    uint256 pk = vm.envUint("PRIVATE_KEY");

    bytes32 salt = bytes32(0);

    bytes memory initCode = abi.encodePacked(type(ImplicitProjectRegistry).creationCode);
    _deployIfNotAlready("ImplicitProjectRegistry", initCode, salt, pk);
  }

}

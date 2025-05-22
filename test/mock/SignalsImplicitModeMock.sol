// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { SignalsImplicitMode } from "src/helper/SignalsImplicitMode.sol";

contract SignalsImplicitModeMock is SignalsImplicitMode {

  constructor(address registry, bytes32 projectId) {
    _initializeSignalsImplicitMode(registry, projectId);
  }

}

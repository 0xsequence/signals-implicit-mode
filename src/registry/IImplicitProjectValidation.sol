// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { Attestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

interface IImplicitProjectValidation {

  /// @notice Invalid redirect url error
  error InvalidRedirectUrl();

  /// @notice Check if a project has a code
  /// @param wallet The wallet address
  /// @param attestation The attestation
  /// @param projectId The project id
  /// @return magic The attestation magic bytes for the wallet address
  function validateAttestation(
    address wallet,
    Attestation calldata attestation,
    bytes32 projectId
  ) external view returns (bytes32);

}

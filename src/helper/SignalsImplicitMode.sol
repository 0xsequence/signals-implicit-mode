// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { Attestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";
import { ISignalsImplicitMode } from "sequence-v3/src/extensions/sessions/implicit/ISignalsImplicitMode.sol";
import { Payload } from "sequence-v3/src/modules/Payload.sol";
import { IImplicitProjectValidation } from "src/registry/IImplicitProjectValidation.sol";
import { ERC165, IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

abstract contract SignalsImplicitMode is ISignalsImplicitMode, ERC165 {

  IImplicitProjectValidation internal _validator;
  bytes32 internal _projectId;

  /// @notice Initialize implicit mode validation
  /// @param validator The IImplicitProjectValidation address
  /// @param projectId The project id
  function _initializeSignalsImplicitMode(address validator, bytes32 projectId) internal {
    _validator = IImplicitProjectValidation(validator);
    _projectId = projectId;
  }

  /// @inheritdoc ISignalsImplicitMode
  function acceptImplicitRequest(
    address wallet,
    Attestation calldata attestation,
    Payload.Call calldata call
  ) external view returns (bytes32) {
    _validateImplicitRequest(wallet, attestation, call);
    return _validator.validateAttestation(wallet, attestation, _projectId);
  }

  /// @notice Validates an implicit request
  /// @dev Optional hook for additional validation of the implicit requests
  /// @param wallet The wallet's address
  /// @param attestation The attestation data
  /// @param call The call to validate
  function _validateImplicitRequest(
    address wallet,
    Attestation calldata attestation,
    Payload.Call calldata call
  ) internal view virtual { }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(ISignalsImplicitMode).interfaceId || super.supportsInterface(interfaceId);
  }

}

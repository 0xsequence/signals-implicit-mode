// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { IImplicitProjectRegistry } from "./IImplicitProjectRegistry.sol";
import { IImplicitProjectValidation } from "./IImplicitProjectValidation.sol";
import { Attestation, LibAttestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

contract ImplicitProjectRegistry is IImplicitProjectRegistry {

  using LibAttestation for Attestation;

  /// @notice Project claimed
  mapping(bytes32 => bool) public projectClaimed;

  /// @notice Project admins
  mapping(bytes32 => mapping(address => bool)) public isProjectAdmin;

  /// @notice Project URLs
  mapping(bytes32 => mapping(bytes32 => bool)) public isProjectUrl;
  mapping(bytes32 => bytes32[]) public projectUrlsList;

  modifier onlyProjectAdmin(
    bytes32 projectId
  ) {
    if (!isProjectAdmin[projectId][msg.sender]) {
      revert IImplicitProjectRegistry.NotProjectAdmin();
    }
    _;
  }

  /// @inheritdoc IImplicitProjectRegistry
  function claimProject(
    bytes12 projectIdUpper
  ) public returns (bytes32 projectId) {
    address admin = msg.sender;
    assembly {
      projectId := or(shl(160, projectIdUpper), admin)
    }
    if (projectClaimed[projectId]) {
      revert IImplicitProjectRegistry.ProjectAlreadyClaimed();
    }
    projectClaimed[projectId] = true;
    isProjectAdmin[projectId][admin] = true;
    emit IImplicitProjectRegistry.ProjectClaimed(projectId, admin);

    return projectId;
  }

  /// @notice Add a project admin
  /// @param projectId The project id
  /// @param admin The admin to add
  function addAdmin(bytes32 projectId, address admin) public onlyProjectAdmin(projectId) {
    if (isProjectAdmin[projectId][admin]) {
      revert IImplicitProjectRegistry.AlreadyProjectAdmin();
    }
    isProjectAdmin[projectId][admin] = true;
    emit IImplicitProjectRegistry.ProjectAdminAdded(projectId, admin);
  }

  /// @notice Remove a project admin
  /// @param projectId The project id
  /// @param admin The admin to remove
  function removeAdmin(bytes32 projectId, address admin) public onlyProjectAdmin(projectId) {
    if (!isProjectAdmin[projectId][admin]) {
      revert IImplicitProjectRegistry.NotProjectAdmin();
    }
    isProjectAdmin[projectId][admin] = false;
    emit IImplicitProjectRegistry.ProjectAdminRemoved(projectId, admin);
  }

  /// @notice Add a project URL hash
  /// @param projectId The project id
  /// @param projectUrlHash The project URL hash
  function addProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) public onlyProjectAdmin(projectId) {
    if (isProjectUrl[projectId][projectUrlHash]) {
      revert IImplicitProjectRegistry.ProjectUrlAlreadyExists();
    }
    isProjectUrl[projectId][projectUrlHash] = true;
    projectUrlsList[projectId].push(projectUrlHash);
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, projectUrlHash);
  }

  /// @inheritdoc IImplicitProjectRegistry
  function addProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectAdmin(projectId) {
    addProjectUrlHash(projectId, _hashUrl(projectUrl));
  }

  /// @notice Remove a project URL hash
  /// @param projectId The project id
  /// @param projectUrlHash The project URL hash
  /// @param urlIdx The index of the project URL hash to remove
  function removeProjectUrlHash(
    bytes32 projectId,
    bytes32 projectUrlHash,
    uint256 urlIdx
  ) public onlyProjectAdmin(projectId) {
    if (!isProjectUrl[projectId][projectUrlHash]) {
      revert IImplicitProjectRegistry.ProjectUrlNotFound();
    }
    if (urlIdx >= projectUrlsList[projectId].length || projectUrlsList[projectId][urlIdx] != projectUrlHash) {
      revert IImplicitProjectRegistry.InvalidProjectUrlIndex();
    }
    isProjectUrl[projectId][projectUrlHash] = false;
    projectUrlsList[projectId][urlIdx] = projectUrlsList[projectId][projectUrlsList[projectId].length - 1];
    projectUrlsList[projectId].pop();
    emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, projectUrlHash);
  }

  /// @inheritdoc IImplicitProjectRegistry
  function removeProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectAdmin(projectId) {
    // Find the index of the project URL hash
    bytes32 projectUrlHash = _hashUrl(projectUrl);
    for (uint256 i; i < projectUrlsList[projectId].length; i++) {
      if (projectUrlsList[projectId][i] == projectUrlHash) {
        removeProjectUrlHash(projectId, projectUrlHash, i);
        return;
      }
    }
    revert IImplicitProjectRegistry.ProjectUrlNotFound();
  }

  /// @inheritdoc IImplicitProjectRegistry
  function listProjectUrls(
    bytes32 projectId
  ) public view returns (bytes32[] memory) {
    return projectUrlsList[projectId];
  }

  /// @inheritdoc IImplicitProjectValidation
  function validateAttestation(
    address wallet,
    Attestation calldata attestation,
    bytes32 projectId
  ) external view returns (bytes32) {
    bytes32 hashedUrl = _hashUrl(attestation.authData.redirectUrl);

    if (isProjectUrl[projectId][hashedUrl]) {
      return attestation.generateImplicitRequestMagic(wallet);
    }

    revert IImplicitProjectValidation.InvalidRedirectUrl();
  }

  function _hashUrl(
    string memory url
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(url));
  }

}

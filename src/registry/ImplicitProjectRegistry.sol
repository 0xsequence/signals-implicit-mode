// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { IImplicitProjectRegistry } from "./IImplicitProjectRegistry.sol";
import { IImplicitProjectValidation } from "./IImplicitProjectValidation.sol";
import { Attestation, LibAttestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

contract ImplicitProjectRegistry is IImplicitProjectRegistry {

  using LibAttestation for Attestation;

  /// @notice Project owner
  mapping(bytes32 => address) public projectOwner;

  /// @notice Project URLs
  mapping(bytes32 => bytes32[]) public projectUrls;

  modifier onlyProjectOwner(
    bytes32 projectId
  ) {
    if (projectOwner[projectId] != msg.sender) {
      revert IImplicitProjectRegistry.NotProjectOwner();
    }
    _;
  }

  /// @inheritdoc IImplicitProjectRegistry
  function claimProject(
    bytes12 projectIdUpper
  ) public returns (bytes32 projectId) {
    address owner = msg.sender;
    assembly {
      projectId := or(shl(160, projectIdUpper), owner)
    }
    if (projectOwner[projectId] != address(0)) {
      revert IImplicitProjectRegistry.ProjectAlreadyClaimed();
    }
    projectOwner[projectId] = owner;
    emit IImplicitProjectRegistry.ProjectClaimed(projectId, owner);

    return projectId;
  }

  /// @inheritdoc IImplicitProjectRegistry
  function transferProject(bytes32 projectId, address newOwner) public onlyProjectOwner(projectId) {
    projectOwner[projectId] = newOwner;
    emit IImplicitProjectRegistry.ProjectOwnerTransferred(projectId, newOwner);
  }

  /// @notice Add a project URL hash
  /// @param projectId The project id
  /// @param projectUrlHash The project URL hash
  function addProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) public onlyProjectOwner(projectId) {
    projectUrls[projectId].push(projectUrlHash);
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, projectUrlHash);
  }

  /// @inheritdoc IImplicitProjectRegistry
  function addProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectOwner(projectId) {
    projectUrls[projectId].push(_hashUrl(projectUrl));
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, _hashUrl(projectUrl));
  }

  /// @notice Remove a project URL hash
  /// @param projectId The project id
  /// @param projectUrlHash The project URL hash
  function removeProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) public onlyProjectOwner(projectId) {
    bytes32[] storage urls = projectUrls[projectId];
    uint256 length = urls.length;

    if (length == 0) {
      revert IImplicitProjectRegistry.ProjectUrlNotFound();
    }

    // Find and remove the URL by replacing it with the last element
    for (uint256 i; i < length; i++) {
      if (urls[i] == projectUrlHash) {
        urls[i] = urls[length - 1];
        urls.pop();
        emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, projectUrlHash);
        return;
      }
    }

    revert IImplicitProjectRegistry.ProjectUrlNotFound();
  }

  /// @inheritdoc IImplicitProjectRegistry
  function removeProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectOwner(projectId) {
    removeProjectUrlHash(projectId, _hashUrl(projectUrl));
  }

  /// @inheritdoc IImplicitProjectRegistry
  function listProjectUrls(
    bytes32 projectId
  ) public view returns (bytes32[] memory) {
    return projectUrls[projectId];
  }

  /// @inheritdoc IImplicitProjectValidation
  function validateAttestation(
    address wallet,
    Attestation calldata attestation,
    bytes32 projectId
  ) external view returns (bytes32) {
    bytes32 hashedUrl = _hashUrl(attestation.authData.redirectUrl);
    bytes32[] storage urls = projectUrls[projectId];
    uint256 length = urls.length;

    for (uint256 i; i < length; i++) {
      if (urls[i] == hashedUrl) {
        return attestation.generateImplicitRequestMagic(wallet);
      }
    }

    revert IImplicitProjectValidation.InvalidRedirectUrl();
  }

  function _hashUrl(
    string memory url
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(url));
  }

}

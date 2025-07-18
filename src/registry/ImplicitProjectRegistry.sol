// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { IImplicitProjectRegistry } from "./IImplicitProjectRegistry.sol";
import { IImplicitProjectValidation } from "./IImplicitProjectValidation.sol";

import { Attestation, LibAttestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

/// @title ImplicitProjectRegistry
/// @author Michael Standen
/// @notice Registry of projects supporting implicit sessions
contract ImplicitProjectRegistry is IImplicitProjectRegistry {

  using LibAttestation for Attestation;

  /// @notice Project owner
  mapping(bytes32 => address) public projectOwner;

  /// @notice Project URLs
  mapping(bytes32 => mapping(bytes32 => bool)) public isProjectUrl;
  mapping(bytes32 => bytes32[]) public projectUrlsList;

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
    if (owner == address(0)) {
      revert IImplicitProjectRegistry.InvalidProjectOwner();
    }
    projectId = bytes32(abi.encodePacked(projectIdUpper, owner));
    if (projectOwner[projectId] != address(0)) {
      revert IImplicitProjectRegistry.ProjectAlreadyClaimed();
    }
    projectOwner[projectId] = owner;
    emit IImplicitProjectRegistry.ProjectClaimed(projectId, owner);

    return projectId;
  }

  /// @inheritdoc IImplicitProjectRegistry
  function transferProject(bytes32 projectId, address newOwner) public onlyProjectOwner(projectId) {
    if (newOwner == address(0)) {
      revert IImplicitProjectRegistry.InvalidProjectOwner();
    }
    projectOwner[projectId] = newOwner;
    emit IImplicitProjectRegistry.ProjectOwnerTransferred(projectId, newOwner);
  }

  function _addProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) internal {
    if (isProjectUrl[projectId][projectUrlHash]) {
      revert IImplicitProjectRegistry.ProjectUrlAlreadyExists();
    }
    isProjectUrl[projectId][projectUrlHash] = true;
    projectUrlsList[projectId].push(projectUrlHash);
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, projectUrlHash);
  }

  /// @notice Add a project URL hash
  /// @param projectId The project id
  /// @param projectUrlHash The project URL hash
  function addProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) external onlyProjectOwner(projectId) {
    _addProjectUrlHash(projectId, projectUrlHash);
  }

  /// @notice Add a list of project URL hashes
  /// @param projectId The project id
  /// @param projectUrlHashes The project URL hashes
  function addProjectUrlHashBatch(
    bytes32 projectId,
    bytes32[] memory projectUrlHashes
  ) external onlyProjectOwner(projectId) {
    for (uint256 i; i < projectUrlHashes.length; i++) {
      _addProjectUrlHash(projectId, projectUrlHashes[i]);
    }
  }

  /// @inheritdoc IImplicitProjectRegistry
  function addProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectOwner(projectId) {
    _addProjectUrlHash(projectId, _hashUrl(projectUrl));
  }

  /// @notice Add a list of project URLs
  /// @param projectId The project id
  /// @param projectUrls The project URLs
  function addProjectUrlBatch(bytes32 projectId, string[] memory projectUrls) external onlyProjectOwner(projectId) {
    for (uint256 i; i < projectUrls.length; i++) {
      _addProjectUrlHash(projectId, _hashUrl(projectUrls[i]));
    }
  }

  function _removeProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash, uint256 urlIdx) internal {
    if (urlIdx >= projectUrlsList[projectId].length || projectUrlsList[projectId][urlIdx] != projectUrlHash) {
      revert IImplicitProjectRegistry.InvalidProjectUrlIndex();
    }
    isProjectUrl[projectId][projectUrlHash] = false;
    projectUrlsList[projectId][urlIdx] = projectUrlsList[projectId][projectUrlsList[projectId].length - 1];
    projectUrlsList[projectId].pop();
    emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, projectUrlHash);
  }

  /// @notice Remove a project URL hash
  /// @param projectId The project id
  /// @param projectUrlHash The project URL hash
  /// @param urlIdx The index of the project URL hash to remove
  function removeProjectUrlHash(
    bytes32 projectId,
    bytes32 projectUrlHash,
    uint256 urlIdx
  ) external onlyProjectOwner(projectId) {
    _removeProjectUrlHash(projectId, projectUrlHash, urlIdx);
  }

  /// @notice Remove a list of project URL hashes
  /// @param projectId The project id
  /// @param projectUrlHashes The project URL hashes
  /// @param urlIdxs The indexes of the project URL hashes to remove
  /// @dev The urlIdxs must be sorted in descending order
  function removeProjectUrlHashBatch(
    bytes32 projectId,
    bytes32[] memory projectUrlHashes,
    uint256[] memory urlIdxs
  ) external onlyProjectOwner(projectId) {
    if (projectUrlHashes.length != urlIdxs.length) {
      revert IImplicitProjectRegistry.InvalidProjectUrlIndex();
    }
    // Ensure the urlIdxs are sorted descending to prevent issues with reordering during removals
    for (uint256 i; i < urlIdxs.length - 1; i++) {
      if (urlIdxs[i] < urlIdxs[i + 1]) {
        revert IImplicitProjectRegistry.InvalidProjectUrlIndex();
      }
    }
    for (uint256 i; i < projectUrlHashes.length; i++) {
      _removeProjectUrlHash(projectId, projectUrlHashes[i], urlIdxs[i]);
    }
  }

  /// @inheritdoc IImplicitProjectRegistry
  /// @dev This function is not optimized. Prefer to use removeProjectUrlHash.
  function removeProjectUrl(bytes32 projectId, string memory projectUrl) external onlyProjectOwner(projectId) {
    // Find the index of the project URL hash
    bytes32 projectUrlHash = _hashUrl(projectUrl);
    for (uint256 i; i < projectUrlsList[projectId].length; i++) {
      if (projectUrlsList[projectId][i] == projectUrlHash) {
        _removeProjectUrlHash(projectId, projectUrlHash, i);
        return;
      }
    }
    revert IImplicitProjectRegistry.ProjectUrlNotFound();
  }

  /// @inheritdoc IImplicitProjectRegistry
  function listProjectUrls(
    bytes32 projectId
  ) external view returns (bytes32[] memory) {
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

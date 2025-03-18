// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { IImplicitProjectValidation } from "src/registry/IImplicitProjectValidation.sol";

interface IImplicitProjectRegistry is IImplicitProjectValidation {

  /// @notice Claim a project
  /// @param projectIdUpper The project id upper
  /// @return projectId The concatenation of the `projectIdUpper` and the `msg.sender`
  function claimProject(
    bytes12 projectIdUpper
  ) external returns (bytes32 projectId);

  /// @notice Add an admin to a project
  /// @param projectId The project id
  /// @param admin The admin to add
  function addAdmin(bytes32 projectId, address admin) external;

  /// @notice Remove an admin from a project
  /// @param projectId The project id
  /// @param admin The admin to remove
  function removeAdmin(bytes32 projectId, address admin) external;

  /// @notice Add a project URL
  /// @param projectId The project id
  /// @param projectUrl The project URL
  function addProjectUrl(bytes32 projectId, string memory projectUrl) external;

  /// @notice Remove a project URL
  /// @param projectId The project id
  /// @param projectUrl The project URL
  function removeProjectUrl(bytes32 projectId, string memory projectUrl) external;

  /// @notice List project URLs
  /// @param projectId The project id
  /// @return projectUrls The project URLs
  function listProjectUrls(
    bytes32 projectId
  ) external view returns (bytes32[] memory);

  /// @notice Not project admin error
  error NotProjectAdmin();

  /// @notice Already project admin error
  error AlreadyProjectAdmin();

  /// @notice Project already claimed error
  error ProjectAlreadyClaimed();

  /// @notice Project URL not found error
  error ProjectUrlNotFound();

  /// @notice Project URL already exists error
  error ProjectUrlAlreadyExists();

  /// @notice Invalid project URL index error
  error InvalidProjectUrlIndex();

  /// @notice Emitted when a project is claimed
  event ProjectClaimed(bytes32 indexed projectId, address indexed owner);

  /// @notice Emitted when a project admin is added
  event ProjectAdminAdded(bytes32 indexed projectId, address indexed admin);

  /// @notice Emitted when a project admin is removed
  event ProjectAdminRemoved(bytes32 indexed projectId, address indexed admin);

  /// @notice Emitted when a project URL is added
  event ProjectUrlAdded(bytes32 indexed projectId, bytes32 indexed urlHash);

  /// @notice Emitted when a project URL is removed
  event ProjectUrlRemoved(bytes32 indexed projectId, bytes32 indexed urlHash);

}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IImplicitRegistry} from "./IImplicitRegistry.sol";
import {Attestation, LibAttestation} from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

error NotProjectOwner();
error ProjectAlreadyClaimed();
error ProjectUrlNotFound();

event ProjectClaimed(bytes32 indexed projectId, address indexed owner);

event ProjectOwnerTransferred(bytes32 indexed projectId, address indexed newOwner);

event ProjectUrlAdded(bytes32 indexed projectId, bytes32 indexed urlHash);

event ProjectUrlRemoved(bytes32 indexed projectId, bytes32 indexed urlHash);

contract ImplicitRegistry is IImplicitRegistry {
    using LibAttestation for Attestation;

    mapping(bytes32 => address) public projectOwner;
    mapping(bytes32 => bytes32[]) public projectUrls;

    modifier onlyProjectOwner(bytes32 projectId) {
        if (projectOwner[projectId] != msg.sender) revert NotProjectOwner();
        _;
    }

    /// @notice Claim a project
    /// @param projectId The project id
    function claimProject(bytes32 projectId) public {
        if (projectOwner[projectId] != address(0)) revert ProjectAlreadyClaimed();
        projectOwner[projectId] = msg.sender;
        emit ProjectClaimed(projectId, msg.sender);
    }

    /// @notice Transfer a project
    /// @param projectId The project id
    /// @param newOwner The new owner
    function transferProject(bytes32 projectId, address newOwner) public onlyProjectOwner(projectId) {
        projectOwner[projectId] = newOwner;
        emit ProjectOwnerTransferred(projectId, newOwner);
    }

    /// @notice Add a project URL
    /// @param projectId The project id
    /// @param projectUrlHash The hash of the project URL to add
    function addProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) public onlyProjectOwner(projectId) {
        projectUrls[projectId].push(projectUrlHash);
        emit ProjectUrlAdded(projectId, projectUrlHash);
    }

    /// @notice Add a project URL
    /// @param projectId The project id
    /// @param projectUrl The project URL to add
    function addProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectOwner(projectId) {
        projectUrls[projectId].push(_hashUrl(projectUrl));
        emit ProjectUrlAdded(projectId, _hashUrl(projectUrl));
    }

    /// @notice Remove a project URL
    /// @param projectId The project id
    /// @param projectUrlHash The hash of the project URL to remove
    function removeProjectUrlHash(bytes32 projectId, bytes32 projectUrlHash) public onlyProjectOwner(projectId) {
        // Remove the project URL from the project URLs array
        bool removed = false;
        bytes32[] memory newProjectUrls = new bytes32[](projectUrls[projectId].length - 1);
        for (uint256 i = 0; i < projectUrls[projectId].length; i++) {
            if (projectUrls[projectId][i] != projectUrlHash) {
                newProjectUrls[i] = projectUrls[projectId][i];
            } else {
                removed = true;
            }
        }
        if (!removed) {
            revert ProjectUrlNotFound();
        }
        projectUrls[projectId] = newProjectUrls;
        emit ProjectUrlRemoved(projectId, projectUrlHash);
    }

    /// @notice Remove a project URL
    /// @param projectId The project id
    /// @param projectUrl The project URL to remove
    function removeProjectUrl(bytes32 projectId, string memory projectUrl) public onlyProjectOwner(projectId) {
        removeProjectUrlHash(projectId, _hashUrl(projectUrl));
    }

    /// @inheritdoc IImplicitRegistry
    function validateProjectUrl(address wallet, Attestation calldata attestation, bytes32 projectId)
        external
        view
        returns (bytes32)
    {
        bytes32 hashedUrl = _hashUrl(attestation.authData.redirectUrl);
        for (uint256 i = 0; i < projectUrls[projectId].length; i++) {
            if (projectUrls[projectId][i] == hashedUrl) {
                return attestation.generateImplicitRequestMagic(wallet);
            }
        }
        revert InvalidRedirectUrl();
    }

    function _hashUrl(string memory url) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(url));
    }
}

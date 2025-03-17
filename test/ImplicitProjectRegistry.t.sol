// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { SignalsImplicitModeMock } from "./mock/SignalsImplicitModeMock.sol";
import { Test, console } from "forge-std/Test.sol";

import { IImplicitProjectRegistry } from "src/registry/IImplicitProjectRegistry.sol";
import { IImplicitProjectValidation } from "src/registry/IImplicitProjectValidation.sol";
import { ImplicitProjectRegistry } from "src/registry/ImplicitProjectRegistry.sol";

import { Attestation, LibAttestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

contract ImplicitProjectRegistryTest is Test {

  using LibAttestation for Attestation;

  ImplicitProjectRegistry public registry;

  function setUp() public {
    registry = new ImplicitProjectRegistry();
  }

  // Positive Tests

  function test_claimProject(address owner, bytes32 projectId) public {
    vm.assume(owner != address(0));

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectClaimed(projectId, owner);

    vm.prank(owner);
    registry.claimProject(projectId);

    assertEq(registry.projectOwner(projectId), owner);
  }

  function test_transferProject(address owner, address newOwner, bytes32 projectId) public {
    vm.assume(owner != address(0) && newOwner != address(0) && owner != newOwner);

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectOwnerTransferred(projectId, newOwner);

    vm.prank(owner);
    registry.transferProject(projectId, newOwner);

    assertEq(registry.projectOwner(projectId), newOwner);
  }

  function test_addProjectUrl(address owner, bytes32 projectId, string memory url) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, _hashUrl(url));

    vm.prank(owner);
    registry.addProjectUrl(projectId, url);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls[0], _hashUrl(url));
  }

  function test_addProjectUrlHash(address owner, bytes32 projectId, bytes32 urlHash) public {
    vm.assume(owner != address(0));

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, urlHash);

    vm.prank(owner);
    registry.addProjectUrlHash(projectId, urlHash);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls[0], urlHash);
  }

  function test_removeProjectUrl(address owner, bytes32 projectId, string memory url) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    vm.prank(owner);
    registry.claimProject(projectId);
    vm.prank(owner);
    registry.addProjectUrl(projectId, url);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, _hashUrl(url));

    vm.prank(owner);
    registry.removeProjectUrl(projectId, url);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls.length, 0);
  }

  function test_validateAttestation(address owner, address wallet, bytes32 projectId, string memory url) public {
    vm.assume(owner != address(0) && wallet != address(0));
    vm.assume(bytes(url).length > 0);

    Attestation memory attestation;
    attestation.authData.redirectUrl = url;

    vm.prank(owner);
    registry.claimProject(projectId);
    vm.prank(owner);
    registry.addProjectUrl(projectId, url);

    bytes32 magic = registry.validateAttestation(wallet, attestation, projectId);
    assertEq(magic, attestation.generateImplicitRequestMagic(wallet));
  }

  // Negative Tests

  function test_fail_claimProjectTwice(address owner, address otherUser, bytes32 projectId) public {
    vm.assume(owner != address(0) && otherUser != address(0) && owner != otherUser);

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectRevert(IImplicitProjectRegistry.ProjectAlreadyClaimed.selector);
    vm.prank(otherUser);
    registry.claimProject(projectId);
  }

  function test_fail_transferProjectByNonOwner(
    address owner,
    address nonOwner,
    address newOwner,
    bytes32 projectId
  ) public {
    vm.assume(owner != address(0) && nonOwner != address(0) && newOwner != address(0));
    vm.assume(owner != nonOwner && owner != newOwner && nonOwner != newOwner);

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.transferProject(projectId, newOwner);
  }

  function test_fail_addProjectUrlByNonOwner(
    address owner,
    address nonOwner,
    bytes32 projectId,
    string memory url
  ) public {
    vm.assume(owner != address(0) && nonOwner != address(0) && owner != nonOwner);
    vm.assume(bytes(url).length > 0);

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.addProjectUrl(projectId, url);
  }

  function test_fail_removeNonexistentUrl(address owner, bytes32 projectId, string memory url) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    vm.prank(owner);
    registry.claimProject(projectId);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlNotFound.selector);
    vm.prank(owner);
    registry.removeProjectUrl(projectId, url);
  }

  function test_fail_validateAttestationWithInvalidUrl(
    address owner,
    address wallet,
    bytes32 projectId,
    string memory validUrl,
    string memory invalidUrl
  ) public {
    vm.assume(owner != address(0) && wallet != address(0));
    vm.assume(bytes(validUrl).length > 0 && bytes(invalidUrl).length > 0);
    vm.assume(keccak256(bytes(validUrl)) != keccak256(bytes(invalidUrl)));

    vm.prank(owner);
    registry.claimProject(projectId);

    Attestation memory attestation;
    attestation.authData.redirectUrl = invalidUrl;

    vm.prank(owner);
    registry.addProjectUrl(projectId, validUrl);

    vm.expectRevert(IImplicitProjectValidation.InvalidRedirectUrl.selector);
    registry.validateAttestation(wallet, attestation, projectId);
  }

  // Helper function
  function _hashUrl(
    string memory url
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(url));
  }

}

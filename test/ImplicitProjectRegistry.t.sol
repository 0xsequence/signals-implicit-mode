// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { TestHelper } from "./TestHelper.sol";
import { SignalsImplicitModeMock } from "./mock/SignalsImplicitModeMock.sol";
import { Test, console } from "forge-std/Test.sol";

import { IImplicitProjectRegistry } from "src/registry/IImplicitProjectRegistry.sol";
import { IImplicitProjectValidation } from "src/registry/IImplicitProjectValidation.sol";
import { ImplicitProjectRegistry } from "src/registry/ImplicitProjectRegistry.sol";

import { Attestation, LibAttestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

contract ImplicitProjectRegistryTest is Test, TestHelper {

  using LibAttestation for Attestation;

  ImplicitProjectRegistry public registry;

  function setUp() public {
    registry = new ImplicitProjectRegistry();
  }

  // Positive Tests

  function test_claimProject(address admin, bytes12 projectIdUpper) public {
    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectClaimed(projectId, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    assertTrue(registry.isProjectAdmin(projectId, admin));
  }

  function test_addAdmin(address initialAdmin, address newAdmin, bytes12 projectIdUpper) public {
    vm.assume(initialAdmin != newAdmin);

    bytes32 projectId = _projectId(projectIdUpper, initialAdmin);

    vm.prank(initialAdmin);
    registry.claimProject(projectIdUpper);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectAdminAdded(projectId, newAdmin);

    vm.prank(initialAdmin);
    registry.addAdmin(projectId, newAdmin);

    assertTrue(registry.isProjectAdmin(projectId, newAdmin));

    // Check functions now work with the new admin
    vm.prank(newAdmin);
    registry.addProjectUrlHash(projectId, bytes32(uint256(1)));
    assertEq(registry.listProjectUrls(projectId).length, 1);
  }

  function test_removeAdmin(address initialAdmin, address secondAdmin, bytes12 projectIdUpper) public {
    vm.assume(initialAdmin != secondAdmin);

    bytes32 projectId = _projectId(projectIdUpper, initialAdmin);

    vm.startPrank(initialAdmin);
    registry.claimProject(projectIdUpper);
    registry.addAdmin(projectId, secondAdmin);
    vm.stopPrank();

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectAdminRemoved(projectId, secondAdmin);

    vm.prank(initialAdmin);
    registry.removeAdmin(projectId, secondAdmin);

    assertFalse(registry.isProjectAdmin(projectId, secondAdmin));
  }

  function test_addProjectUrl(address admin, bytes12 projectIdUpper, string memory url) public {
    vm.assume(bytes(url).length > 0);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, _hashUrl(url));

    vm.prank(admin);
    registry.addProjectUrl(projectId, url);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    urls = _deduplicateBytes32Array(urls);
    assertEq(urls[0], _hashUrl(url));
  }

  function test_addProjectUrlHash(address admin, bytes12 projectIdUpper, bytes32 urlHash) public {
    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, urlHash);

    vm.prank(admin);
    registry.addProjectUrlHash(projectId, urlHash);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls[0], urlHash);
  }

  function test_removeProjectUrl(address admin, bytes12 projectIdUpper, string[] memory urls, uint256 urlIdx) public {
    vm.assume(urls.length > 0);
    // Max 10 urls
    if (urls.length > 10) {
      assembly {
        mstore(urls, 10)
      }
    }
    urls = _deduplicateStringArray(urls);
    urlIdx = bound(urlIdx, 0, urls.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urls.length; i++) {
      registry.addProjectUrl(projectId, urls[i]);
    }

    bytes32 urlHash = _hashUrl(urls[urlIdx]);
    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, urlHash);

    registry.removeProjectUrl(projectId, urls[urlIdx]);
    vm.stopPrank();

    bytes32[] memory actualUrls = registry.listProjectUrls(projectId);
    assertEq(actualUrls.length, urls.length - 1);
    for (uint256 i; i < actualUrls.length; i++) {
      assertNotEq(actualUrls[i], urlHash);
    }
  }

  function test_removeProjectUrlHash(
    address admin,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes,
    uint256 urlHashIdx
  ) public {
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);
    urlHashIdx = bound(urlHashIdx, 0, urlHashes.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urlHashes.length; i++) {
      registry.addProjectUrlHash(projectId, urlHashes[i]);
    }

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, urlHashes[urlHashIdx]);

    registry.removeProjectUrlHash(projectId, urlHashes[urlHashIdx], urlHashIdx);
    vm.stopPrank();

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls.length, urlHashes.length - 1);
    for (uint256 i; i < urls.length; i++) {
      assertNotEq(urls[i], urlHashes[urlHashIdx]);
    }
  }

  function test_validateAttestationSingle(
    address admin,
    address wallet,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(bytes(url).length > 0);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    Attestation memory attestation;
    attestation.authData.redirectUrl = url;

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();

    bytes32 magic = registry.validateAttestation(wallet, attestation, projectId);
    assertEq(magic, attestation.generateImplicitRequestMagic(wallet));
  }

  function test_validateAttestationMultiple(
    address admin,
    address wallet,
    bytes12 projectIdUpper,
    string[] memory urls,
    uint256 urlIdx
  ) public {
    vm.assume(urls.length > 0);
    // Max 10 urls
    if (urls.length > 10) {
      assembly {
        mstore(urls, 10)
      }
    }
    urls = _deduplicateStringArray(urls);
    urlIdx = bound(urlIdx, 0, urls.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    Attestation memory attestation;
    attestation.authData.redirectUrl = urls[urlIdx];

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urls.length; i++) {
      registry.addProjectUrl(projectId, urls[i]);
    }
    vm.stopPrank();

    bytes32 magic = registry.validateAttestation(wallet, attestation, projectId);
    assertEq(magic, attestation.generateImplicitRequestMagic(wallet));
  }

  // Negative Tests

  function test_fail_claimProjectTwice(address admin, bytes12 projectIdUpper) public {
    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);

    // Remove self as admin
    registry.removeAdmin(projectId, admin);

    // Attempt to reclaim
    vm.expectRevert(IImplicitProjectRegistry.ProjectAlreadyClaimed.selector);
    registry.claimProject(projectIdUpper);
  }

  function test_fail_addAdminByNonAdmin(
    address admin,
    address nonAdmin,
    address newAdmin,
    bytes12 projectIdUpper
  ) public {
    vm.assume(admin != nonAdmin && admin != newAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(nonAdmin);
    registry.addAdmin(projectId, newAdmin);
  }

  function test_fail_addAdminTwice(address admin, bytes12 projectIdUpper) public {
    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.AlreadyProjectAdmin.selector);
    registry.addAdmin(projectId, admin);
    vm.stopPrank();
  }

  function test_fail_removeNonAdmin(address admin, address nonAdmin, bytes12 projectIdUpper) public {
    vm.assume(admin != nonAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(admin);
    registry.removeAdmin(projectId, nonAdmin);
  }

  function test_fail_removeAdminByNonAdmin(address admin, address nonAdmin, bytes12 projectIdUpper) public {
    vm.assume(admin != nonAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(nonAdmin);
    registry.removeAdmin(projectId, admin);
  }

  function test_fail_addProjectUrlByNonAdmin(
    address admin,
    address nonAdmin,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(admin != nonAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(nonAdmin);
    registry.addProjectUrl(projectId, url);
  }

  function test_fail_addProjectUrlHashByNonAdmin(
    address admin,
    address nonAdmin,
    bytes12 projectIdUpper,
    bytes32 urlHash
  ) public {
    vm.assume(admin != nonAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(nonAdmin);
    registry.addProjectUrlHash(projectId, urlHash);
  }

  function test_fail_removeProjectUrlByNonAdmin(
    address admin,
    address nonAdmin,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(admin != nonAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(nonAdmin);
    registry.removeProjectUrl(projectId, url);
  }

  function test_fail_removeProjectUrlHashByNonAdmin(
    address admin,
    address nonAdmin,
    bytes12 projectIdUpper,
    bytes32 urlHash
  ) public {
    vm.assume(admin != nonAdmin);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectAdmin.selector);
    vm.prank(nonAdmin);
    registry.removeProjectUrlHash(projectId, urlHash, 0);
  }

  function test_fail_addProjectUrlAlreadyExists(address admin, bytes12 projectIdUpper, string memory url) public {
    vm.assume(bytes(url).length > 0);

    vm.startPrank(admin);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();
  }

  function test_fail_addProjectUrlHashAlreadyExists(address admin, bytes12 projectIdUpper, bytes32 urlHash) public {
    vm.startPrank(admin);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrlHash(projectId, urlHash);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrlHash(projectId, urlHash);
    vm.stopPrank();
  }

  function test_fail_addProjectUrlAlreadyExistsHash(address admin, bytes12 projectIdUpper, string memory url) public {
    vm.startPrank(admin);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrlHash(projectId, _hashUrl(url));

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();
  }

  function test_fail_addProjectUrlHashAlreadyExistsFull(
    address admin,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.startPrank(admin);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrlHash(projectId, _hashUrl(url));
    vm.stopPrank();
  }

  function test_fail_removeNonexistentUrl(address admin, bytes12 projectIdUpper, string memory url) public {
    vm.assume(bytes(url).length > 0);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlNotFound.selector);
    vm.prank(admin);
    registry.removeProjectUrl(projectId, url);
  }

  function test_fail_removeNonexistentUrlHash(address admin, bytes12 projectIdUpper, bytes32 urlHash) public {
    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlNotFound.selector);
    vm.prank(admin);
    registry.removeProjectUrlHash(projectId, urlHash, 0);
  }

  function test_fail_removeUrlHashWrongIndex(
    address admin,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes,
    uint256 urlHashIdx
  ) public {
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);
    urlHashIdx = bound(urlHashIdx, 0, urlHashes.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.startPrank(admin);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urlHashes.length; i++) {
      registry.addProjectUrlHash(projectId, urlHashes[i]);
    }
    vm.stopPrank();

    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectUrlIndex.selector);
    vm.prank(admin);
    registry.removeProjectUrlHash(projectId, urlHashes[urlHashIdx], urlHashIdx + 1);
  }

  function test_fail_validateAttestationWithInvalidUrl(
    address admin,
    address wallet,
    bytes12 projectIdUpper,
    string memory validUrl,
    string memory invalidUrl
  ) public {
    vm.assume(bytes(validUrl).length > 0 && bytes(invalidUrl).length > 0);
    vm.assume(keccak256(bytes(validUrl)) != keccak256(bytes(invalidUrl)));

    bytes32 projectId = _projectId(projectIdUpper, admin);

    vm.prank(admin);
    registry.claimProject(projectIdUpper);

    Attestation memory attestation;
    attestation.authData.redirectUrl = invalidUrl;

    vm.prank(admin);
    registry.addProjectUrl(projectId, validUrl);

    vm.expectRevert(IImplicitProjectValidation.InvalidRedirectUrl.selector);
    registry.validateAttestation(wallet, attestation, projectId);
  }

}

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

  function test_claimProject(address owner, bytes12 projectIdUpper) public {
    vm.assume(owner != address(0));
    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectClaimed(projectId, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    assertEq(registry.projectOwner(projectId), owner);
  }

  function test_transferProject(address owner, address newOwner, bytes12 projectIdUpper, bytes32 urlHash) public {
    vm.assume(owner != address(0));
    vm.assume(newOwner != address(0));
    vm.assume(owner != newOwner);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectOwnerTransferred(projectId, newOwner);

    vm.prank(owner);
    registry.transferProject(projectId, newOwner);

    assertEq(registry.projectOwner(projectId), newOwner);

    // Check functions now work with the new owner
    vm.prank(newOwner);
    registry.addProjectUrlHash(projectId, urlHash);
    assertEq(registry.listProjectUrls(projectId).length, 1);
  }

  function test_addProjectUrl(address owner, bytes12 projectIdUpper, string memory url) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, _hashUrl(url));

    vm.prank(owner);
    registry.addProjectUrl(projectId, url);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    urls = _deduplicateBytes32Array(urls);
    assertEq(urls[0], _hashUrl(url));
  }

  function test_addProjectUrlBatch(address owner, bytes12 projectIdUpper, string[] memory urls) public {
    vm.assume(owner != address(0));
    vm.assume(urls.length > 0);
    // Max 10 urls
    if (urls.length > 10) {
      assembly {
        mstore(urls, 10)
      }
    }
    urls = _deduplicateStringArray(urls);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);

    for (uint256 i; i < urls.length; i++) {
      vm.expectEmit();
      emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, _hashUrl(urls[i]));
    }

    registry.addProjectUrlBatch(projectId, urls);
    vm.stopPrank();

    bytes32[] memory actualUrls = registry.listProjectUrls(projectId);
    assertEq(actualUrls.length, urls.length);
    for (uint256 i; i < actualUrls.length; i++) {
      assertEq(actualUrls[i], _hashUrl(urls[i]));
    }
  }

  function test_addProjectUrlHash(address owner, bytes12 projectIdUpper, bytes32 urlHash) public {
    vm.assume(owner != address(0));
    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectEmit();
    emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, urlHash);

    vm.prank(owner);
    registry.addProjectUrlHash(projectId, urlHash);

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls[0], urlHash);
  }

  function test_addProjectUrlHashBatch(address owner, bytes12 projectIdUpper, bytes32[] memory urlHashes) public {
    vm.assume(owner != address(0));
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);

    for (uint256 i; i < urlHashes.length; i++) {
      vm.expectEmit();
      emit IImplicitProjectRegistry.ProjectUrlAdded(projectId, urlHashes[i]);
    }

    registry.addProjectUrlHashBatch(projectId, urlHashes);
    vm.stopPrank();

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls.length, urlHashes.length);
    for (uint256 i; i < urls.length; i++) {
      assertEq(urls[i], urlHashes[i]);
    }
  }

  function test_removeProjectUrl(address owner, bytes12 projectIdUpper, string[] memory urls, uint256 urlIdx) public {
    vm.assume(owner != address(0));
    vm.assume(urls.length > 0);
    // Max 10 urls
    if (urls.length > 10) {
      assembly {
        mstore(urls, 10)
      }
    }
    urls = _deduplicateStringArray(urls);
    urlIdx = bound(urlIdx, 0, urls.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
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
    address owner,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes,
    uint256 urlHashIdx
  ) public {
    vm.assume(owner != address(0));
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);
    urlHashIdx = bound(urlHashIdx, 0, urlHashes.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
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

  function test_removeProjectUrlHashBatch(address owner, bytes12 projectIdUpper, bytes32[] memory urlHashes) public {
    vm.assume(owner != address(0));
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);
    registry.addProjectUrlHashBatch(projectId, urlHashes);

    // Reverse the urlHashes list
    bytes32[] memory reversedUrlHashes = new bytes32[](urlHashes.length);
    for (uint256 i; i < urlHashes.length; i++) {
      reversedUrlHashes[i] = urlHashes[urlHashes.length - i - 1];
    }

    uint256[] memory urlIdxs = new uint256[](urlHashes.length);
    for (uint256 i; i < urlHashes.length; i++) {
      urlIdxs[i] = urlHashes.length - i - 1;
    }

    for (uint256 i; i < urlHashes.length; i++) {
      vm.expectEmit();
      emit IImplicitProjectRegistry.ProjectUrlRemoved(projectId, reversedUrlHashes[i]);
    }
    registry.removeProjectUrlHashBatch(projectId, reversedUrlHashes, urlIdxs);
    vm.stopPrank();

    bytes32[] memory urls = registry.listProjectUrls(projectId);
    assertEq(urls.length, 0);
  }

  function test_removeProjectUrlHashBatchWithInvalidUrlIdxs(
    address owner,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes,
    uint256[] memory urlIdxs
  ) public {
    vm.assume(owner != address(0));
    vm.assume(urlHashes.length > 0);
    vm.assume(urlIdxs.length > 0);
    vm.assume(urlIdxs.length != urlHashes.length);

    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectUrlIndex.selector);
    registry.removeProjectUrlHashBatch(projectId, urlHashes, urlIdxs);
    vm.stopPrank();
  }

  function test_removeProjectUrlHashBatchWithInvalidUrlIdxsOrder(
    address owner,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes,
    uint256[] memory urlIdxs
  ) public {
    vm.assume(owner != address(0));
    uint256 idxsLength = urlIdxs.length;
    vm.assume(idxsLength > 1);
    assembly {
      mstore(urlHashes, idxsLength)
    }

    bool isUnsorted = false;
    for (uint256 i; i < urlIdxs.length - 1; i++) {
      if (urlIdxs[i] < urlIdxs[i + 1]) {
        isUnsorted = true;
        break;
      }
    }
    vm.assume(isUnsorted);

    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectUrlIndex.selector);
    registry.removeProjectUrlHashBatch(projectId, urlHashes, urlIdxs);
    vm.stopPrank();
  }

  function test_validateAttestationSingle(
    address owner,
    address wallet,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    Attestation memory attestation;
    attestation.authData.redirectUrl = url;

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();

    bytes32 magic = registry.validateAttestation(wallet, attestation, projectId);
    assertEq(magic, attestation.generateImplicitRequestMagic(wallet));
  }

  function test_validateAttestationMultiple(
    address owner,
    address wallet,
    bytes12 projectIdUpper,
    string[] memory urls,
    uint256 urlIdx
  ) public {
    vm.assume(owner != address(0));
    vm.assume(urls.length > 0);
    // Max 10 urls
    if (urls.length > 10) {
      assembly {
        mstore(urls, 10)
      }
    }
    urls = _deduplicateStringArray(urls);
    urlIdx = bound(urlIdx, 0, urls.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    Attestation memory attestation;
    attestation.authData.redirectUrl = urls[urlIdx];

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urls.length; i++) {
      registry.addProjectUrl(projectId, urls[i]);
    }
    vm.stopPrank();

    bytes32 magic = registry.validateAttestation(wallet, attestation, projectId);
    assertEq(magic, attestation.generateImplicitRequestMagic(wallet));
  }

  // Negative Tests

  function test_fail_claimInvalidOwner(
    bytes12 projectIdUpper
  ) public {
    address owner = address(0);

    vm.prank(owner);
    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectOwner.selector);
    registry.claimProject(projectIdUpper);
  }

  function test_fail_transferInvalidOwner(address owner, bytes12 projectIdUpper) public {
    vm.assume(owner != address(0));
    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.prank(owner);
    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectOwner.selector);
    registry.transferProject(projectId, address(0));
  }

  function test_fail_claimProjectTwice(address owner, address otherUser, bytes12 projectIdUpper) public {
    vm.assume(owner != otherUser);
    vm.assume(owner != address(0));
    vm.assume(otherUser != address(0));

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    // Transfer the project to the other user
    vm.prank(owner);
    registry.transferProject(projectId, otherUser);

    // Attempt to reclaim
    vm.expectRevert(IImplicitProjectRegistry.ProjectAlreadyClaimed.selector);
    vm.prank(owner);
    registry.claimProject(projectIdUpper);
  }

  function test_fail_transferByNonAdmin(address owner, address nonOwner, bytes12 projectIdUpper) public {
    vm.assume(owner != nonOwner);
    vm.assume(owner != address(0));
    vm.assume(nonOwner != address(0));

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.transferProject(projectId, nonOwner);
  }

  function test_fail_addProjectUrlByNonOwner(
    address owner,
    address nonOwner,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(owner != address(0));
    vm.assume(owner != nonOwner);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.addProjectUrl(projectId, url);
  }

  function test_fail_addProjectUrlHashByNonOwner(
    address owner,
    address nonOwner,
    bytes12 projectIdUpper,
    bytes32 urlHash
  ) public {
    vm.assume(owner != address(0));
    vm.assume(owner != nonOwner);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.addProjectUrlHash(projectId, urlHash);
  }

  function test_fail_removeProjectUrlByNonOwner(
    address owner,
    address nonOwner,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(owner != address(0));
    vm.assume(owner != nonOwner);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.removeProjectUrl(projectId, url);
  }

  function test_fail_removeProjectUrlHashByNonOwner(
    address owner,
    address nonOwner,
    bytes12 projectIdUpper,
    bytes32 urlHash
  ) public {
    vm.assume(owner != address(0));
    vm.assume(owner != nonOwner);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.removeProjectUrlHash(projectId, urlHash, 0);
  }

  function test_fail_addProjectUrlHashBatchByNonOwner(
    address owner,
    address nonOwner,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes
  ) public {
    vm.assume(owner != address(0));
    vm.assume(owner != nonOwner);
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.addProjectUrlHashBatch(projectId, urlHashes);
  }

  function test_fail_removeProjectUrlHashBatchByNonOwner(
    address owner,
    address nonOwner,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes
  ) public {
    vm.assume(owner != address(0));
    vm.assume(owner != nonOwner);
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);
    uint256[] memory urlIdxs = new uint256[](urlHashes.length);
    for (uint256 i; i < urlHashes.length; i++) {
      urlIdxs[i] = i;
    }

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urlHashes.length; i++) {
      registry.addProjectUrlHash(projectId, urlHashes[i]);
    }
    vm.stopPrank();

    vm.expectRevert(IImplicitProjectRegistry.NotProjectOwner.selector);
    vm.prank(nonOwner);
    registry.removeProjectUrlHashBatch(projectId, urlHashes, urlIdxs);
  }

  function test_fail_addProjectUrlAlreadyExists(address owner, bytes12 projectIdUpper, string memory url) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();
  }

  function test_fail_addProjectUrlHashAlreadyExists(address owner, bytes12 projectIdUpper, bytes32 urlHash) public {
    vm.assume(owner != address(0));
    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrlHash(projectId, urlHash);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrlHash(projectId, urlHash);
    vm.stopPrank();
  }

  function test_fail_addProjectUrlAlreadyExistsHash(address owner, bytes12 projectIdUpper, string memory url) public {
    vm.assume(owner != address(0));
    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrlHash(projectId, _hashUrl(url));

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();
  }

  function test_fail_addProjectUrlHashAlreadyExistsFull(
    address owner,
    bytes12 projectIdUpper,
    string memory url
  ) public {
    vm.assume(owner != address(0));
    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlAlreadyExists.selector);
    registry.addProjectUrlHash(projectId, _hashUrl(url));
    vm.stopPrank();
  }

  function test_fail_removeNonexistentUrl(address owner, bytes12 projectIdUpper, string memory url) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(url).length > 0);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.ProjectUrlNotFound.selector);
    vm.prank(owner);
    registry.removeProjectUrl(projectId, url);
  }

  function test_fail_removeNonexistentUrlHash(address owner, bytes12 projectIdUpper, bytes32 urlHash) public {
    vm.assume(owner != address(0));
    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectUrlIndex.selector);
    vm.prank(owner);
    registry.removeProjectUrlHash(projectId, urlHash, 0);
  }

  function test_fail_removeUrlHashWrongIndex(
    address owner,
    bytes12 projectIdUpper,
    bytes32[] memory urlHashes,
    uint256 urlHashIdx
  ) public {
    vm.assume(owner != address(0));
    vm.assume(urlHashes.length > 0);
    // Max 10 urls
    if (urlHashes.length > 10) {
      assembly {
        mstore(urlHashes, 10)
      }
    }
    urlHashes = _deduplicateBytes32Array(urlHashes);
    urlHashIdx = bound(urlHashIdx, 0, urlHashes.length - 1);

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.startPrank(owner);
    registry.claimProject(projectIdUpper);
    for (uint256 i; i < urlHashes.length; i++) {
      registry.addProjectUrlHash(projectId, urlHashes[i]);
    }
    vm.stopPrank();

    vm.expectRevert(IImplicitProjectRegistry.InvalidProjectUrlIndex.selector);
    vm.prank(owner);
    registry.removeProjectUrlHash(projectId, urlHashes[urlHashIdx], urlHashIdx + 1);
  }

  function test_fail_validateAttestationWithInvalidUrl(
    address owner,
    address wallet,
    bytes12 projectIdUpper,
    string memory validUrl,
    string memory invalidUrl
  ) public {
    vm.assume(owner != address(0));
    vm.assume(bytes(validUrl).length > 0 && bytes(invalidUrl).length > 0);
    vm.assume(keccak256(bytes(validUrl)) != keccak256(bytes(invalidUrl)));

    bytes32 projectId = _projectId(projectIdUpper, owner);

    vm.prank(owner);
    registry.claimProject(projectIdUpper);

    Attestation memory attestation;
    attestation.authData.redirectUrl = invalidUrl;

    vm.prank(owner);
    registry.addProjectUrl(projectId, validUrl);

    vm.expectRevert(IImplicitProjectValidation.InvalidRedirectUrl.selector);
    registry.validateAttestation(wallet, attestation, projectId);
  }

}

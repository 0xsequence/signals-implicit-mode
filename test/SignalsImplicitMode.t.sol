// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import { SignalsImplicitModeMock } from "./mock/SignalsImplicitModeMock.sol";
import { Test, console } from "forge-std/Test.sol";

import { IImplicitProjectValidation } from "src/registry/IImplicitProjectValidation.sol";
import { ImplicitProjectRegistry } from "src/registry/ImplicitProjectRegistry.sol";

import { Attestation, LibAttestation } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";
import { Payload } from "sequence-v3/src/modules/Payload.sol";

contract SignalsImplicitModeTest is Test {

  using LibAttestation for Attestation;

  SignalsImplicitModeMock public signalsImplicitMode;
  ImplicitProjectRegistry public registry;

  function setUp() public {
    registry = new ImplicitProjectRegistry();
  }

  function test_acceptsValidUrl(
    bytes12 projectIdUpper,
    address owner,
    string memory url,
    Attestation memory attestation,
    address wallet,
    Payload.Call memory call
  ) public {
    attestation.authData.redirectUrl = url;

    // Claim the project and add the url
    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    registry.addProjectUrl(projectId, url);
    vm.stopPrank();

    // Initialize the signals implicit mode
    signalsImplicitMode = new SignalsImplicitModeMock(address(registry), projectId);

    // Accept the implicit request
    bytes32 expectedMagic = attestation.generateImplicitRequestMagic(wallet);
    bytes32 actualMagic = signalsImplicitMode.acceptImplicitRequest(wallet, attestation, call);
    assertEq(actualMagic, expectedMagic);
  }

  function test_acceptsValidUrlFromMultiple(
    bytes12 projectIdUpper,
    address owner,
    string[] memory urls,
    uint256 urlIdx,
    Attestation memory attestation,
    address wallet,
    Payload.Call memory call
  ) public {
    vm.assume(urls.length > 0);
    // Max 10 urls
    if (urls.length > 10) {
      assembly {
        mstore(urls, 10)
      }
    }
    urlIdx = bound(urlIdx, 0, urls.length - 1);

    attestation.authData.redirectUrl = urls[urlIdx];

    // Claim the project and add the url
    vm.startPrank(owner);
    bytes32 projectId = registry.claimProject(projectIdUpper);
    for (uint256 i; i < urls.length; i++) {
      registry.addProjectUrl(projectId, urls[i]);
    }
    vm.stopPrank();

    // Initialize the signals implicit mode
    signalsImplicitMode = new SignalsImplicitModeMock(address(registry), projectId);

    // Accept the implicit request
    bytes32 expectedMagic = attestation.generateImplicitRequestMagic(wallet);
    bytes32 actualMagic = signalsImplicitMode.acceptImplicitRequest(wallet, attestation, call);
    assertEq(actualMagic, expectedMagic);
  }

  function test_rejectsInvalidUrl(
    bytes32 projectId,
    string memory url,
    Attestation memory attestation,
    address wallet,
    Payload.Call memory call
  ) public {
    signalsImplicitMode = new SignalsImplicitModeMock(address(registry), projectId);
    attestation.authData.redirectUrl = url;

    // Accept the implicit request
    vm.expectRevert(abi.encodeWithSelector(IImplicitProjectValidation.InvalidRedirectUrl.selector));
    signalsImplicitMode.acceptImplicitRequest(wallet, attestation, call);
  }

}

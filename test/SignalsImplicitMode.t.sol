// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SignalsImplicitModeMock} from "./mock/SignalsImplicitModeMock.sol";

import {ImplicitRegistry} from "src/registry/ImplicitRegistry.sol";
import {IImplicitRegistry} from "src/registry/IImplicitRegistry.sol";

import {Attestation, LibAttestation} from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";
import {Payload} from "sequence-v3/src/modules/Payload.sol";

contract SignalsImplicitModeTest is Test {
    using LibAttestation for Attestation;

    SignalsImplicitModeMock public signalsImplicitMode;
    ImplicitRegistry public registry;

    function setUp() public {
        registry = new ImplicitRegistry();
    }

    function test_acceptsValidUrl(
        bytes32 projectId,
        string memory url,
        Attestation memory attestation,
        address wallet,
        Payload.Call memory call
    ) public {
        signalsImplicitMode = new SignalsImplicitModeMock(address(registry), projectId);
        attestation.authData.redirectUrl = url;

        // Claim the project and add the url
        registry.claimProject(projectId);
        registry.addProjectUrl(projectId, url);

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
        vm.expectRevert(abi.encodeWithSelector(IImplicitRegistry.InvalidRedirectUrl.selector));
        signalsImplicitMode.acceptImplicitRequest(wallet, attestation, call);
    }
}

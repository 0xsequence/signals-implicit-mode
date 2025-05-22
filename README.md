# Signals Implicit Mode

Libraries for managing support for [Sequence Ecosystem Wallet](https://github.com/0xsequence/sequence-v3)'s [implicit sessions](https://github.com/0xsequence/sequence-v3/blob/master/docs/SESSIONS.md).

## Implicit Registry

The `ImplicitProjectRegistry` is an ownerless, singleton contract that allows a single contract to define the accepted `redirectUrl`s for their project. Using the registry gives a single point for management of accepted `redirectUrl`s. 

Using the registry is also a quick way to authorize implicit access to contracts from other projects. 

See below *Support Implicit Sessions* for information on how to integrate with the registry. 

### Register Your Project URLs

Select your `Project ID`. The project ID is composed of two parts:
- A 12-byte (24 hex characters) upper portion that you choose
- Your address as the lower 20 bytes

To claim your project ID, call the `claimProject(bytes12 projectIdUpper)` function. The contract will automatically combine your chosen upper portion with your address to create the full project ID.

> [!TIP]
> Consider claiming your project ID on every chain you wish to support. Claiming a project ID does not imply you must use it.

As the project owner, you can:
- Add supported redirect URLs by calling `addProjectUrl(bytes32 projectId, string memory projectUrl)`
- Remove URLs using `removeProjectUrl(bytes32 projectId, string memory projectUrl)`
- Transfer project ownership using `transferProject(bytes32 projectId, address newOwner)`

Anyone can list all project URLs using `listProjectUrls(bytes32 projectId)`.

Integrate your contracts with the registry using your project ID as described in the next section.

## Support Implicit Sessions

Import this library into your project using forge.

```sh
cd <your-project>
forge install https://github.com/0xsequence/signals-implicit-mode
```

Extend the provided abstract contract implementation.

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {SignalsImplicitMode} from "signals-implicit-mode/helper/SignalsImplicitMode.sol";

contract ImplicitSupportedContract is SignalsImplicitMode {
    constructor(address registry, bytes32 projectId) {
        _initializeSignalsImplicitMode(registry, projectId);
    }
}
```

Optionally, extend the validation by implementing the `_validateImplicitRequest` hook.

## Run Tests

```sh
forge test
```

## Deploy Contracts

> [!NOTE]
> This will deploy the `ImplicitProjectRegistry`. Deployments use ERC-2470 for counter factual deployments and will deploy to `0x88132015f17526dA2119F1Efb8BAC818b2CcA2Eb`.

> [!TIP]
> The `ImplicitProjectRegistry` is ownerless and so you are free to use an implementation and claim any `projectId`. You do not need to deploy your own instance.

Copy the `env.sample` file to `.env` and set the environment variables.

```sh
cp .env.sample .env
# Edit .env
```

```sh
forge script Deploy --rpc-url <xxx> --broadcast
```

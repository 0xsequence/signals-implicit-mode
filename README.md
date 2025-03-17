# Signals Implicit Mode

Libraries for managing support for [Sequence Ecosystem Wallet](https://github.com/0xsequence/sequence-v3)'s [implicit sessions](https://github.com/0xsequence/sequence-v3/blob/master/docs/SESSIONS.md).

## Implicit Registry

The `ImplicitRegistry` is an ownerless, singleton contract that allows a single contract to define the accepted `redirectUrl`s for their project. Using the registry gives a single point for management of accepted `redirectUrl`s. 

Using the registry is also a quick way to authorize implicit access to contracts from other projects. 

See below *Support Implicit Sessions* for information on how to integrate with the registry. 

### Register Your Project URLs

Select your `Project ID`. This can be any `bytes32`. Check the current registry to ensure there is no collision with an existing project. 

To claim your project ID, call the `claimProject(bytes32 projectId)` function.

> [!TIP]
> Consider claiming your project ID on every chain you wish to support. Claiming a project ID does not imply you must use it.

Add supported redirect URLs by calling the `addProjectUrl(bytes32 projectId, string memory projectUrl)` function. 

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
    constructor(address registry, bytes32 projectId) SignalsImplicitMode(registry, projectId) {}
}
```

Optionally, extend the validation by implementing the `_validateImplicitRequest` hook.

## Run Tests

```sh
forge test
```

## Deploy Contracts

> [!NOTE]
> This will deploy the `ImplicitRegistry`. Deployments use ERC-2470 for counter factual deployments and will deploy to `0x85625a67eec5b18Fb0Bbcd0DA41c813882A183B1`.

> [!TIP]
> The `ImplicitRegistry` is ownerless and so you are free to use an implementation and claim any `projectId`. You do not need to deploy your own instance.

Copy the `env.sample` file to `.env` and set the environment variables.

```sh
cp .env.sample .env
# Edit .env
```

```sh
forge script Deploy --rpc-url <xxx> --broadcast
```

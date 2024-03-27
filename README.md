<p align='center'>
<img src="https://avatars.githubusercontent.com/u/103565959" alt="CrossSync Logo" width="60" height="60" />
</p>

<h1  align='center'>Upgrade via Multisig Contract</h1>


## Introduction

This repository is an implementation of a multisig contract that can be applied in general scenarios. 


## Usage

### Build

```shell
npm i
forge install
forge build
```

### Test

```shell
forge test
```


### Deploy

```shell
forge script script/Deploy.s.sol:Deploy \
--chain-id $CHAIN_ID \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--verifier-url $VERIFIER_URL \
--verifier $VERIFIER \
--verify \
--broadcast --ffi -vvvv 

# generate easily readable abi to /deployments
forge script script/Deploy.s.sol:Deploy --sig 'sync()' --rpc-url $RPC_URL --broadcast --ffi
```


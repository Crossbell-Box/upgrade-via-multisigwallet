<p align='center'>
<img src="https://avatars.githubusercontent.com/u/103565959" alt="CrossSync Logo" width="60" height="60" />
</p>

<h1  align='center'>Upgrade via Multisig Contract</h1>


## Introduction

This repository is an implementation of a multisig contract that can be applied in general scenarios. 

Currently, this multisig contract is used to upgrade contracts. Crossbell-Box has several upgradeable contracts, which are previously controlled by the admin of TransparentUpgradeableProxy contracts. Having a this proxy contract controlled by a single address is not safe nor reasonable. So we transferred the ownership of TransparentUpgradeableProxy contract to this multisig contract.

Currently, this multisig contract has 2 functionalities: `upgrade` and `change admin`. For proxy contracts that are already deployed, you need to call `changeAdmin` function and change the admin to this multisig contract. For new proxy contracts, you can directly input the multisig contract address into `constructor` when deploying. Complete usages can be found in [test cases](https://github.com/Crossbell-Box/upgrade-via-multisigwallet/blob/main/test/ProxyAdminMultisig.t.sol).

Specifically, the information generated from **social activities** will be the initial form of data-ownership by users on Crossbell.

## ⚙ Development

```shell
yarn
yarn test
```
Install forge if you don't have one:
```shell
# install foge
curl -L https://foundry.paradigm.xyz | bash
foundryup
```
Compile and run test:
```shell
make
# or
make test
# or run sigle test function using --match-test
forge test --match-test testXXX  -vvvvv
```
Deploy:
```shell
chmod +x  ./scripts/deploy_XXX.sh 
deploy_XXX.sh
```


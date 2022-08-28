# things need to be considered:

## what proxyAdmin contract is used for?
proxyAdmin is admin of TransparentUpgradeableProxy
   
   proxyAdmin can:

   1. upgrade implementation logic
   2. change the admin (what if you change the owner of proxyAdmin into alice?)

## change the owner of proxyAdmin into alice
call proxyAdmin.upgrade => [FAIL. Reason: Ownable: caller is not the owner]

(proxyAdmin is ownable, `transferOwnership` should be called)

problem solved:

when you want to transfer the power of upgrading into someone else, you should only change the owner of ProxyAdmin contract, and you don't need to change the admin of TransparentUpgradeableProxy!!

the logic goes:

`the owner of ProxyAdmin` controls => `ProxyAdmin`

`ProxyAdmin` controls => `TransparentUpgradeableProxy`

   

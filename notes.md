# things need to be considered:

## what proxyAdmin contract is used for?
proxyAdmin is admin of TransparentUpgradeableProxy
   
   proxyAdmin can:

   1. upgrade implementation logic
   2. change the admin (what if you change the owner of proxyAdmin into alice?)

## change the owner of proxyAdmin into alice
call proxyAdmin.upgrade => [FAIL. Reason: Ownable: caller is not the owner]

proxyAdmin is ownable, `transferOwnership` should be called
   

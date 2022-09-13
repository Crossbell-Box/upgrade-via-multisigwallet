import { ethers } from "hardhat";

async function main() {
    const [owner] = await ethers.getSigners();

    // update owners and threshold when deploying
    const owners = [0xa6f969045641Cf486a747A2688F3a5A6d43cd0D8, 0xa6f969045641Cf486a747A2688F3a5A6d43cd0D7,0xa6f969045641Cf486a747A2688F3a5A6d43cd0D9];
    const threshold = 2;

    const ProxyAdminMultisig = await ethers.getContractFactory("ProxyAdminMultisig");
    const proxyAdminMultisig = await ProxyAdminMultisig.deploy(owners, threshold);

    await proxyAdminMultisig.deployed();
    console.log("proxyAdminMultisig deployed to:", proxyAdminMultisig.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
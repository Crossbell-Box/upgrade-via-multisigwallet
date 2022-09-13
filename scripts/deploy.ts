import { ethers } from "hardhat";

async function main() {
    const [owner] = await ethers.getSigners();

    // update owners and threshold when deploying
    const owners = ["0x3B6D02A24Df681FFdf621D35D70ABa7adaAc07c1", "0xE01c8D2Abc0f6680cB3eaBD8a77A616Bc5e085f7","0xda2423ceA4f1047556e7a142F81a7ED50e93e160"];
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
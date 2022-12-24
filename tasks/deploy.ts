import { task } from "hardhat/config"
import { TaskArguments } from "hardhat/types"
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address"
import { assert } from "console";

import { SpaceCoinICO } from "../src/types/SpaceCoinICO"
import { SpaceCoinToken } from "../src/types/SpaceCoinToken"
import { SpaceRouter } from "../src/types/SpaceRouter"
import { SpaceCoinICO__factory } from "../src/types/factories/SpaceCoinICO__factory"
import { SpaceCoinToken__factory } from "../src/types/factories/SpaceCoinToken__factory"
import { SpaceRouter__factory } from "../src/types/factories/SpaceRouter__factory"


task("deploy")
  .addOptionalVariadicPositionalParam("whitelist", "The addresses of the whitelisted investors")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const signers: SignerWithAddress[] = await ethers.getSigners()
    assert(signers.length >= 2)
    const deployer = signers[0]


    const tokenFactory: SpaceCoinToken__factory = <SpaceCoinToken__factory>await ethers.getContractFactory("SpaceCoinToken");
    const token: SpaceCoinToken = <SpaceCoinToken>await tokenFactory.connect(deployer).deploy(signers[1].address);
    await token.deployed();
    console.log("SpaceCoinToken deployed to: ", token.address);

    const icoFactory: SpaceCoinICO__factory = <SpaceCoinICO__factory>await ethers.getContractFactory("SpaceCoinICO");
    const ico: SpaceCoinICO = <SpaceCoinICO>await icoFactory.connect(deployer).deploy(token.address, taskArguments.whitelist ?? []);
    await ico.deployed();
    console.log("SpaceCoinICO deployed to: ", ico.address);


    const routerFactory = <SpaceRouter__factory>await ethers.getContractFactory("SpaceRouter");
    const router = <SpaceRouter>await routerFactory.connect(deployer).deploy(token.address);
    await router.deployed();
    const poolAddress = await router.pool();
    console.log("SpaceRouter deployed to: ", router.address);
    console.log("SpaceLP deployed to: ", poolAddress);

  });

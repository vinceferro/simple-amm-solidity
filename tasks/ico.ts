import { task } from "hardhat/config"
import { TaskArguments } from "hardhat/types"
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address"

import { SpaceCoinToken } from "../src/types/SpaceCoinToken"
import { SpaceCoinToken__factory } from "../src/types/factories/SpaceCoinToken__factory"

import { SpaceCoinICO } from "../src/types/SpaceCoinICO"
import { SpaceCoinICO__factory } from "../src/types/factories/SpaceCoinICO__factory"

import { assert } from "console";

task("ico:fund")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const signers: SignerWithAddress[] = await ethers.getSigners()
    assert(signers.length >= 2)
    const treasury = signers[1]
    const tokenAddress : string = process.env.TOKEN_ADDRESS || "0x0000000000000000000000000000000000000000";
    const icoAddress : string = process.env.ICO_ADDRESS || "0x0000000000000000000000000000000000000000";
    const tokenFactory: SpaceCoinToken__factory = <SpaceCoinToken__factory>await ethers.getContractFactory("SpaceCoinToken")
    const token: SpaceCoinToken = <SpaceCoinToken>await tokenFactory.attach(tokenAddress)
    await token.connect(treasury).transfer(icoAddress, ethers.utils.parseEther("30000").mul(5))
    console.log("SpaceCoinICO funded")
  });

  task("ico:toggle")
  .setAction(async function (_taskArguments: TaskArguments, { ethers }) {
    const signers: SignerWithAddress[] = await ethers.getSigners()
    assert(signers.length >= 2)
    const deployer = signers[0]
    const icoAddress : string = process.env.ICO_ADDRESS || "0x0000000000000000000000000000000000000000";
    const ico = await SpaceCoinICO__factory.connect(icoAddress, deployer)
    const toggledTx = await ico.toggleFundraisingEnabled()
    console.log(toggledTx)
  });
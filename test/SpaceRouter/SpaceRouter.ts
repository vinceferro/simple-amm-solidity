import { artifacts, ethers, waffle } from "hardhat"
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address"
import type { SpaceCoinToken } from "../../src/types/SpaceCoinToken"

import { Signers } from "../types"
import { shouldBehaveLikeSpaceRouter } from "./SpaceRouter.behavior"


describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers
    const signers: SignerWithAddress[] = await ethers.getSigners()
    this.signers = {
        deployer: signers[0],
        treasury: signers[1],
        provider: signers[2],
        trader: signers[3],
    }

    const tokenArtifact = await artifacts.readArtifact("SpaceCoinToken")
    this.routerArtifact = await artifacts.readArtifact("SpaceRouter")
    this.token = <SpaceCoinToken>await waffle.deployContract(this.signers.deployer, tokenArtifact, [this.signers.treasury.address])
    await this.token.connect(this.signers.treasury).transfer(this.signers.provider.address, ethers.utils.parseEther("100"))
  });

  describe("SpaceRouter", function () {
    shouldBehaveLikeSpaceRouter()
  });
})

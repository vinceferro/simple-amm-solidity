import { expect } from "chai"
import { ethers, waffle } from "hardhat"

import type { SpaceRouter } from "../../src/types/SpaceRouter"
import type { SpaceLP } from "../../src/types/SpaceLP"
import { SpaceLP__factory } from "../../src/types/factories/SpaceLP__factory"


export function shouldBehaveLikeSpaceRouter(): void {
  beforeEach(async function () {
    this.router = <SpaceRouter>await waffle.deployContract(this.signers.deployer, this.routerArtifact, [this.token.address])
    this.pool = <SpaceLP>SpaceLP__factory.connect(await this.router.pool(), this.signers.deployer)
  })

  it("should allow add liquidity and burn", async function () {
    const amountSPC = ethers.utils.parseEther("150")
    const amountETH = amountSPC.div(5)
    await this.token.connect(this.signers.treasury).approve(this.router.address, amountSPC)
    await expect(() => this.router.connect(this.signers.treasury).addLiquidity(amountETH, amountSPC, {value: amountETH})).to
        .changeEtherBalance(
            this.signers.treasury, amountETH.mul(-1)
        )
    
    await this.pool.connect(this.signers.treasury).approve(this.router.address, ethers.utils.parseEther("1"))
    await expect(() => this.router.connect(this.signers.treasury).removeLiquidity(
        ethers.utils.parseEther("1"),
        ethers.utils.parseEther("0.03"),
        ethers.utils.parseEther("0.006"),
    )).to.changeTokenBalance(
        this.pool,
        this.signers.treasury,
        ethers.utils.parseEther("-1")
    )
  })

  it("should allow trader to swap", async function () {
    const amountSPC = ethers.utils.parseEther("150")
    const amountETH = amountSPC.div(5)
    await this.token.connect(this.signers.treasury).approve(this.router.address, amountSPC)
    await expect(() => this.router.connect(this.signers.treasury).addLiquidity(amountETH, amountSPC, {value: amountETH})).to
        .changeEtherBalance(
            this.signers.treasury, amountETH.mul(-1)
        )

    const ethIn = ethers.utils.parseEther("1")
    const minSpcOut = ethIn.mul(4)
    await expect(() => this.router.connect(this.signers.trader).swapETHforSPC(ethIn, minSpcOut, {value: ethIn})).to.changeTokenBalance(
        this.token,
        this.signers.trader,
        "4791868344627299128",
    )
  })

  it("should block undersidered swap", async function () {
    const amountSPC = ethers.utils.parseEther("150")
    const amountETH = amountSPC.div(5)
    await this.token.connect(this.signers.treasury).approve(this.router.address, amountSPC)
    await expect(() => this.router.connect(this.signers.treasury).addLiquidity(amountETH, amountSPC, {value: amountETH})).to
        .changeEtherBalance(
            this.signers.treasury, amountETH.mul(-1)
        )

    const ethIn = ethers.utils.parseEther("1")
    const minSpcOut = ethIn.mul(5)
    await expect(this.router.connect(this.signers.trader).swapETHforSPC(ethIn, minSpcOut, {value: ethIn})).to.revertedWith("E_INVALID_OUT_AMOUNTS")
  })

}


import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address"
import type { Fixture } from "ethereum-waffle"
import type { Artifact } from "hardhat/types"
import type { SpaceCoinToken } from "../src/types/SpaceCoinToken"
import type { SpaceLP } from "../src/types/SpaceLP"
import type { SpaceRouter } from "../src/types/SpaceRouter"

declare module "mocha" {
  export interface Context {
    routerArtifact: Artifact;
    router: SpaceRouter;
    token: SpaceCoinToken;
    pool: SpaceLP;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  deployer: SignerWithAddress;
  treasury: SignerWithAddress;
  provider: SignerWithAddress;
  trader: SignerWithAddress;
}

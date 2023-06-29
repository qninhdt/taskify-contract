import { ethers } from "hardhat"
import {
  TKFToken,
  TKFToken__factory,
  TaskElection,
  TaskElection__factory,
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"

function TKF(amount: number) {
  return ethers.utils.parseEther(amount.toString())
}

describe("TaskElection", () => {
  let TaskElection: TaskElection__factory,
    taskElection: TaskElection,
    TKFToken: TKFToken__factory,
    tkfToken: TKFToken,
    owner: SignerWithAddress,
    users: SignerWithAddress[]

  async function deloyContracts() {
    TKFToken = await ethers.getContractFactory("TKFToken")
    tkfToken = await TKFToken.deploy()

    TaskElection = await ethers.getContractFactory("TaskElection")
    taskElection = await TaskElection.deploy(tkfToken.address)

    const addressList = await ethers.getSigners()
    owner = addressList[0]
    users = [addressList[1], addressList[2], addressList[3], addressList[4]]
  }

  it("Should have the right owner", async () => {
    await deloyContracts()
    expect(await taskElection.owner()).to.equal(owner.address)
    expect(await tkfToken.owner()).to.equal(owner.address)
  })

  describe("TKFToken", () => {
    it("Should send 1000 TKF to owner", async () => {
      await tkfToken.buyTokens({ value: TKF(1000).div(1000) })
      expect(await tkfToken.balanceOf(owner.address)).to.equal(TKF(1000))
    })

    it("Should transfer 100 TKF from owner to 4 users", async () => {
      for (let i = 0; i < 4; i++) {
        await tkfToken.transfer(users[i].address, TKF(100))
        expect(await tkfToken.balanceOf(users[i].address)).to.equal(TKF(100))
      }
      expect(await tkfToken.balanceOf(owner.address)).to.equal(TKF(600))
    })
  })

  describe("Election 1 (two users vote candidate 0, two other users vote candidate 1, candidate 1 wins)", () => {
    it("Should be created", async () => {
      await tkfToken.approve(taskElection.address, TKF(15))

      await taskElection.createElection(
        "https://example.com",
        "Election 1",
        "Election 1 description",
        TKF(15),
        ["Candidate 1", "Candidate 2"],
      )

      const election = await taskElection.elections(0)
      expect(election.id).to.equal(0)
      expect(election.picture).to.equal("https://example.com")
      expect(election.title).to.equal("Election 1")
      expect(election.description).to.equal("Election 1 description")
      expect(election.reward).to.equal(TKF(15))
      expect(election.state).to.equal(0)
      expect(election.numCandidates).to.equal(2)
    })

    it("Should have right author", async () => {
      expect((await taskElection.elections(0)).author).to.equal(owner.address)
    })

    it("Should correctly record and retrieve votes for candidates", async () => {
      // user3 & user4 vote for candidate 2
      // user1 & user2 vote for candidate 1
      const votes = [
        [0, TKF(1)],
        [0, TKF(2)],
        [1, TKF(2)],
        [1, TKF(4)],
      ]

      for (let i = 0; i < 4; i++) {
        await tkfToken
          .connect(users[i])
          .approve(taskElection.address, votes[i][1])
        await taskElection
          .connect(users[i])
          .castVote(0, votes[i][0], votes[i][1])
      }

      for (let i = 0; i < 4; i++) {
        const vote = await taskElection.connect(users[i]).getMyVote(0)
        expect(vote.candidateId).to.equal(votes[i][0])
        expect(vote.stake).to.equal(votes[i][1])
      }
    })

    it("Should correctly compute result", async () => {
      await taskElection.finalizeElection(0)

      const election = await taskElection.elections(0)
      expect(election.winningCandidateId).to.equal(1)
      expect(election.state).to.equal(1)
    })

    it("Should pay out reward to winners", async () => {
      // totalReward = 15 + 1 + 2 + 2 + 4 = 24 TKF
      // user2 get 24 * 2 / (2 + 4) = 8 TKF
      // user4 get 24 * 4 / (2 + 4) = 16 TKF
      expect(await tkfToken.balanceOf(users[0].address)).to.equal(TKF(100 - 1))
      expect(await tkfToken.balanceOf(users[1].address)).to.equal(TKF(100 - 2))
      expect(await tkfToken.balanceOf(users[2].address)).to.equal(
        TKF(100 - 2 + 8),
      )
      expect(await tkfToken.balanceOf(users[3].address)).to.equal(
        TKF(100 - 4 + 16),
      )
    })
  })

  describe("Election 2 (one user vote candidate 0, one other users vote candidate 1, election is cancelled)", () => {
    async function createElection2() {
      await tkfToken.approve(taskElection.address, TKF(15))

      await taskElection.createElection(
        "https://example.com",
        "Election 2",
        "Election 2 description",
        TKF(15),
        ["Candidate 1", "Candidate 2"],
      )

      const votes = [
        [0, TKF(2)],
        [1, TKF(2)],
      ]

      for (let i = 0; i < 2; i++) {
        await tkfToken
          .connect(users[i])
          .approve(taskElection.address, votes[i][1])
        await taskElection
          .connect(users[i])
          .castVote(1, votes[i][0], votes[i][1])
      }
    }

    let ownerLastBalance: any
    let user1LastBalance: any
    let user2LastBalance: any

    it("Should be cancelled", async () => {
      ownerLastBalance = await tkfToken.balanceOf(owner.address)
      user1LastBalance = await tkfToken.balanceOf(users[0].address)
      user2LastBalance = await tkfToken.balanceOf(users[1].address)

      await createElection2()
      await taskElection.cancelElection(1)

      const election = await taskElection.elections(1)
      expect(election.state).to.equal(2)
    })

    it("Should refund voters", async () => {
      expect(await tkfToken.balanceOf(owner.address)).to.equal(ownerLastBalance)
      expect(await tkfToken.balanceOf(users[0].address)).to.equal(
        user1LastBalance,
      )
      expect(await tkfToken.balanceOf(users[1].address)).to.equal(
        user2LastBalance,
      )
    })
  })
})

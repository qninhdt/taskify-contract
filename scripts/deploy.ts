import { ethers, run } from "hardhat"

async function main() {
  const TKFToken = await ethers.getContractFactory("TKFToken")
  const tkfToken = await TKFToken.deploy()

  const TaskElection = await ethers.getContractFactory("TaskElection")
  const taskElection = await TaskElection.deploy(tkfToken.address)

  await tkfToken.deployed()
  await taskElection.deployed()

  console.log("TKFToken deployed to:", tkfToken.address)
  console.log("TaskElection deployed to:", taskElection.address)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

import "dotenv/config"
import "@nomicfoundation/hardhat-toolbox"
import "hardhat-abi-exporter"

import type { HardhatUserConfig } from "hardhat/config"

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_NETWORK_URL,
      accounts: [process.env.SEPOLIA_PRIVATE_KEY],
    },
  },

  abiExporter: {
    path: "./bin/abi",
    runOnCompile: true,
    clear: true,
    flat: true,
    // only: [":ERC20$"],
    spacing: 2,
    pretty: true,
    // format: "minimal",
  },
}

export default config

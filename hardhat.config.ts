import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
dotenv.config()

let deployer = process.env.DEPLOYER!

const config: HardhatUserConfig = {
  solidity: {
   version: "0.8.20" ,
   settings: {
    optimizer: {
      enabled: true,
      runs: 200,
      
    },
    viaIR: true,
    }
  },
  networks: {
    moonriver: {
      url: 'https://moonriver.public.blastapi.io', // Insert your RPC URL here
      chainId: 1285, // (hex: 0x505),
      accounts: [deployer],
    },
    moonbeam: {
      url: 'https://moonbeam.public.blastapi.io', // Insert your RPC URL here
      chainId: 1284, // (hex: 0x505),
      accounts: [deployer],
    },
  },
};

export default config;

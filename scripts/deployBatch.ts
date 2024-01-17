import { ethers } from "hardhat";

async function main() {
    // Deploy the BatchSwapExecutor contract
    const BatchSwapExecutor = await ethers.getContractFactory("Batch");
    const batchSwapExecutor = await BatchSwapExecutor.deploy();
    // console.log(JSON.stringify(batchSwapExecutor, null, 2));


    await batchSwapExecutor.waitForDeployment();
    // console.log(JSON.stringify(batchSwapExecutor, null, 2));
    let deployedAddress = await batchSwapExecutor.target;
    console.log(`BatchSwapExecutor deployed to: ${JSON.stringify(deployedAddress, null, 2)}`);
  }

  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
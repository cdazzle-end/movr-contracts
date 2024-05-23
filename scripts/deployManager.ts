import { ethers } from "hardhat";

async function main() {
    // Deploy the BatchSwapExecutor contract
    // const BatchSwapExecutor = await ethers.getContractFactory("Batch");
    // const batchSwapExecutor = await BatchSwapExecutor.deploy();
    const managerContract = await ethers.getContractFactory("DexV3Manager");
    const deployReceipt = await managerContract.deploy();
    // console.log(JSON.stringify(batchSwapExecutor, null, 2));


    // await batchSwapExecutor.waitForDeployment();
    deployReceipt.waitForDeployment()
    // console.log(JSON.stringify(batchSwapExecutor, null, 2));
    let deployedAddress = await deployReceipt.target;
    console.log(`DexV3Manager contract deployed to: ${JSON.stringify(deployedAddress, null, 2)}`);
  }

  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
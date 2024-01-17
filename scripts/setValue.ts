import { ethers } from "hardhat";

async function main() {
    // Create instance of the Box contract
    const Box = await ethers.getContractFactory('Box');
  
    // Connect the instance to the deployed contract
    // const box = await Box.attach('0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512');
    const box = await Box.attach('0x2bdCC0de6bE1f7D2ee689a0342D76F52E8EFABa3');
  
    // Store a new value
    await box.store(2);
  
    // Retrieve the value
    const value = await box.retrieve();
    console.log(`The new value is: ${value}`);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
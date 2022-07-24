import { ethers } from "hardhat";

async function main() {

    const [owner] = await ethers.getSigners();

    const Market = await ethers.getContractFactory("Market");
    const market = await Market.deploy();
    await market.deployed();
    await market.initialize(
        owner.address,
        owner.address
    )
    console.log("Market address", market.address);

    const Collection = await ethers.getContractFactory("Collection");
    const ComplexDoNFT = await ethers.getContractFactory("ComplexDoNFT");

    const decentraland = await Collection.deploy(
        "Decentraland",
        "DCL",
        owner.address,
        owner.address
    );
    await decentraland.deployed();
    console.log("Decentraland collection:", decentraland.address);

    const decentralandDoNFT = await ComplexDoNFT.deploy()
    await decentralandDoNFT.deployed()
    decentralandDoNFT.initialize(
        "Decentraland DoNFT",
        "DDCL",
        decentraland.address,
        market.address,
        owner.address,
        owner.address,
        owner.address
    )
    console.log("Decentraland DoNFT:", decentralandDoNFT.address);


    const collection = await Collection.deploy(
        "Axie Infinity",
        "AXI",
        owner.address,
        owner.address
    );
    await collection.deployed();
    console.log("Axie Infinity collection:", collection.address);

    const axieDoNFT = await ComplexDoNFT.deploy()
    await axieDoNFT.deployed()
    axieDoNFT.initialize(
        "Axie Infinity DoNFT",
        "DAXI",
        collection.address,
        market.address,
        owner.address,
        owner.address,
        owner.address
    )
    console.log("Axie Infinity DoNFT:", axieDoNFT.address);



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

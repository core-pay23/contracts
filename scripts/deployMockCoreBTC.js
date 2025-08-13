const { ethers } = require("hardhat");
require("dotenv").config();

// Set these addresses as needed
const paymentGatewayAddress = "0xE49c73e0E3BA8E504572782510850400b57Ae250";

async function main() {
  // Deploy MockCoreBTC
  const MockCoreBTC = await ethers.getContractFactory("MockCoreBTC");
  const mockCoreBTC = await MockCoreBTC.deploy(
    "Mock CoreBTC",
    "coreBTC",
    8 // 8 decimals like Bitcoin
  );
  await mockCoreBTC.deployed();
  const coreBTCAddress = mockCoreBTC.address;
  console.log("MockCoreBTC deployed to:", coreBTCAddress);

  // Add to allowed tokens in PaymentGatewayDirect
  const [deployer] = await ethers.getSigners();
  const paymentGateway = await ethers.getContractAt(
    "PaymentGatewayDirect",
    paymentGatewayAddress,
    deployer
  );
  const tx = await paymentGateway.addAllowedToken(coreBTCAddress);
  await tx.wait();
  console.log("MockCoreBTC added to allowed tokens in PaymentGatewayDirect");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

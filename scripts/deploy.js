const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  // Example values, replace with your actual addresses and tokens
  const taxAddress = "0xB3bC5e0c37f99436b1BAC787faE96a8D0609A170";

  // Deploy MockUSDC
  const MockUSDC = await ethers.getContractFactory("MockUSDC");
  const mockUSDC = await MockUSDC.deploy(
    "Mock USDC",
    "USDC",
    6 // 6 decimals like real USDC
  );
  await mockUSDC.deployed();
  const usdcAddress = mockUSDC.address;
  console.log("MockUSDC deployed to:", usdcAddress);

  const allowedTokens = [usdcAddress];
  const owner = (await ethers.getSigners())[0].address;

  const PaymentGatewayDirect = await ethers.getContractFactory(
    "PaymentGatewayDirect"
  );
  const paymentGateway = await PaymentGatewayDirect.deploy(
    taxAddress,
    allowedTokens,
    owner
  );
  await paymentGateway.deployed();

  console.log("PaymentGatewayDirect deployed to:", paymentGateway.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

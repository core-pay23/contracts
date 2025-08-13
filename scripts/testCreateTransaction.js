
require('dotenv').config();
const { ethers } = require('ethers');

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.CORE_RPC_URL);
  const wallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);

  // PaymentGatewayDirect contract ABI (minimal for createTransaction)
  const abi = [
    "function createTransaction(string _originChain, uint256 _totalPayment, address _shopOwner, address _paymentToken) external returns (uint256)",
    "function payTransactionWithToken(uint256 _transactionId) external returns (bool)",
    "function payTransaction(uint256 _transactionId) external payable",
    "event TransactionCreated(uint256 indexed transactionId, address indexed shopOwner, uint256 totalPayment, string originChain, address paymentToken)",
    "event TransactionPaid(uint256 indexed transactionId, address indexed payer, address indexed shopOwner, address paymentToken, uint256 paymentAmount, uint256 taxAmount)"
  ];

  const contractAddress = "0xE49c73e0E3BA8E504572782510850400b57Ae250";
  const contract = new ethers.Contract(contractAddress, abi, wallet);

  // Test data
  const originChain = "coreTestnet";
  const shopOwner = wallet.address; // For test, use deployer as shop owner
  // Allowed token: mockUSDC
  const mockUSDC = "0xF1FCFF97118ea87Ba99CB5A590d0823651FFFDF1";
  // Native token:
  const nativeToken = "0x0000000000000000000000000000000000000000";

  // Amounts
  const usdcAmount = ethers.utils.parseUnits("1", 6); // 1 USDC (6 decimals)
  const sttAmount = ethers.utils.parseUnits("0.001", 18); // 0.001 STT (18 decimals)

  // Test with mockUSDC
  console.log("Creating transaction with mockUSDC...");
  let tx = await contract.createTransaction(originChain, usdcAmount, shopOwner, mockUSDC);
  let receipt = await tx.wait();
  console.log("mockUSDC Transaction hash:", receipt.hash);
  let mockUsdcTxId;
  const logs = receipt.logs;
  for (const log of logs) {
    try {
      const parsed = contract.interface.parseLog(log);
      if (parsed.name === "TransactionCreated") {
        console.log("mockUSDC TransactionCreated event:", parsed.args);
        mockUsdcTxId = parsed.args[0];
      }
    } catch (e) {}
  }

  // Test with native token
  console.log("Creating transaction with native token (STT)...");
  const totalPayment = sttAmount; // Define totalPayment for native token
  tx = await contract.createTransaction(originChain, totalPayment, shopOwner, nativeToken);
  receipt = await tx.wait();
  console.log("Native token Transaction hash:", receipt.hash);
  let nativeTxId;
  const logs2 = receipt.logs;
  for (const log of logs2) {
    try {
      const parsed = contract.interface.parseLog(log);
      if (parsed.name === "TransactionCreated") {
        console.log("Native token TransactionCreated event:", parsed.args);
        nativeTxId = parsed.args[0];
      }
    } catch (e) {}
  }

  // Pay mockUSDC transaction
  if (mockUsdcTxId) {
    console.log(`Approving PaymentGatewayDirect to spend mockUSDC...`);
    const erc20Abi = ["function approve(address spender, uint256 amount) external returns (bool)"];
  const usdcContract = new ethers.Contract(mockUSDC, erc20Abi, wallet);
    const approveTx = await usdcContract.approve(contractAddress, usdcAmount);
    await approveTx.wait();
    console.log(`Paying mockUSDC transaction ID: ${mockUsdcTxId}`);
    const payTx = await contract.payTransactionWithToken(mockUsdcTxId);
    const payReceipt = await payTx.wait();
    console.log("mockUSDC payTransactionWithToken hash:", payReceipt.hash);
    // Optionally parse logs for TransactionPaid event
    for (const log of payReceipt.logs) {
      try {
        const parsed = contract.interface.parseLog(log);
        if (parsed.name === "TransactionPaid") {
          console.log("mockUSDC TransactionPaid event:", parsed.args);
        }
      } catch (e) {}
    }
  }

  // Pay native token transaction
  if (nativeTxId) {
    console.log(`Paying native token transaction ID: ${nativeTxId}`);
    // For native token, must send value
    const payTx = await contract.payTransaction(nativeTxId, { value: totalPayment });
    const payReceipt = await payTx.wait();
    console.log("Native token payTransaction hash:", payReceipt.hash);
    for (const log of payReceipt.logs) {
      try {
        const parsed = contract.interface.parseLog(log);
        if (parsed.name === "TransactionPaid") {
          console.log("Native token TransactionPaid event:", parsed.args);
        }
      } catch (e) {}
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

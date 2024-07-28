import { ethers } from 'ethers';

// Connect to the Ethereum network
const provider = new ethers.providers.JsonRpcProvider(`http://127.0.0.1:8545`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = '0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB';

// The ABI of the `createNewRequest` method
const contractABI = [
  { "type": "function", "name": "createNewRequest", "inputs": [{ "name": "message", "type": "string", "internalType": "string" }], "outputs": [], "stateMutability": "nonpayable" }
];

// Create a contract instance
const contract = new ethers.Contract(contractAddress, contractABI, wallet);

// Function to generate random messages
function generateRandomMessage(): string {
  const firstParts = ['Hello', 'Hi', 'Good Morning', 'Good Night', 'Bye'];
  const secondParts = ['Darling', 'John', 'Boy', 'Man', 'Eve'];
  const firstPart = firstParts[Math.floor(Math.random() * firstParts.length)];
  const secondPart = secondParts[Math.floor(Math.random() * secondParts.length)];
  const randomMessage = `${firstPart} ${secondPart} ${Math.floor(Math.random() * 1000)}`;
  return randomMessage;
}

async function createNewRequest(message: string) {
  try {
    // Send a transaction to the createNewRequest function
    const tx = await contract.createNewRequest(message);

    // Wait for the transaction to be mined
    const receipt = await tx.wait();

    console.log(`Transaction successful with hash: ${receipt.transactionHash}`);
  } catch (error) {
    console.error('Error sending transaction:', error);
  }
}

// Function to create a new request with a random message every 15 seconds
function startCreatingTasks() {
  setInterval(() => {
    const randomName = generateRandomMessage();
    console.log(`Creating new request with message: ${randomName}`);
    createNewRequest(randomName);
  }, 5000);
}

// Start the process
startCreatingTasks();
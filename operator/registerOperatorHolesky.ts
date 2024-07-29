import { ethers } from "ethers";
import * as dotenv from "dotenv";
import { delegationABI } from "./abis/delegationABI";
import contractABI from "../contracts/out/BlockpostServiceManager.sol/BlockpostServiceManager.json";
import registryABI from "../contracts/out/ECDSAStakeRegistry.sol/ECDSAStakeRegistry.json"
import avsDirectoryABI from "../contracts/out/AVSDirectory.sol/AVSDirectory.json"
dotenv.config();

const provider = new ethers.providers.JsonRpcProvider(process.env.HOLESKY_RPC_URL);
const wallet = new ethers.Wallet(process.env.HOLESKY_PRIVATE_KEY!, provider);
const contractAddress = process.env.HOLESKY_CONTRACT_ADDRESS!;
const stakeRegistryAddress = process.env.HOLESKY_STAKE_REGISTRY_ADDRESS!;
const avsDirectoryAddress = process.env.HOLESKY_AVS_DIRECTORY_ADDRESS!;
const delegationManagerAddress = process.env.HOLESKY_DELEGATION_MANAGER_ADDRESS!;


const delegationManager = new ethers.Contract(delegationManagerAddress, delegationABI, wallet);
const avs = new ethers.Contract(contractAddress, contractABI.abi, wallet);
const registryContract = new ethers.Contract(stakeRegistryAddress, registryABI.abi, wallet);
const avsDirectory = new ethers.Contract(avsDirectoryAddress, avsDirectoryABI.abi, wallet);

const registerOperator = async () => {
    console.log("check")
    console.log("op address: ", wallet.address);
    /*  const tx1 = await delegationManager.registerAsOperator({
         earningsReceiver: wallet.address,
         delegationApprover: "0x0000000000000000000000000000000000000000",
         stakerOptOutWindowBlocks: 0
     }, "");
     await tx1.wait(); */
    console.log("Operator registered on EL successfully");

    const salt = ethers.utils.hexlify(ethers.utils.randomBytes(32));
    const expiry = Math.floor(Date.now() / 1000) + 3600; // Example expiry, 1 hour from now

    // Define the output structure
    let operatorSignature = {
        signature: "",
        salt: salt,
        expiry: expiry,
    };

    // Calculate the digest hash using the avsDirectory's method
    const digestHash = await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
        wallet.address,
        avs.address,
        salt,
        expiry
    );

    console.log(digestHash);
    // Sign the digest hash with the operator's private key
    const signingKey = new ethers.utils.SigningKey(process.env.HOLESKY_PRIVATE_KEY!);
    const signature = signingKey.signDigest(digestHash);

    // Encode the signature in the required format
    operatorSignature.signature = ethers.utils.joinSignature(signature);
    console.log(operatorSignature);
    const tx2 = await registryContract.registerOperatorWithSignature(
        operatorSignature,
        wallet.address,
    );
    await tx2.wait();

    console.log("Operator registered on AVS successfully");
};


const main = async () => {
    try {
        await registerOperator();
    } catch (error) {
        console.log(error);
    }
};

main().catch((error) => {
    console.error("Error in main function:", error);
});
import { ethers } from "ethers";
import * as dotenv from "dotenv";
import { delegationABI } from "./abis/delegationABI";
import contractABI from "../contracts/out/BlockpostServiceManager.sol/BlockpostServiceManager.json";
import registryABI from "../contracts/out/ECDSAStakeRegistry.sol/ECDSAStakeRegistry.json"
import avsDirectoryABI from "../contracts/out/AVSDirectory.sol/AVSDirectory.json"
dotenv.config();

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
const delegationManagerAddress = process.env.DELEGATION_MANAGER_ADDRESS!;
const contractAddress = process.env.CONTRACT_ADDRESS!;
const stakeRegistryAddress = process.env.STAKE_REGISTRY_ADDRESS!;
const avsDirectoryAddress = process.env.AVS_DIRECTORY_ADDRESS!;

const delegationManager = new ethers.Contract(delegationManagerAddress, delegationABI, wallet);
const contract = new ethers.Contract(contractAddress, contractABI.abi, wallet);
const registryContract = new ethers.Contract(stakeRegistryAddress, registryABI.abi, wallet);
const avsDirectory = new ethers.Contract(avsDirectoryAddress, avsDirectoryABI.abi, wallet);

const signAndRespondToRequest = async (requestId: number, requestBlocknumber: number, requestMessage: string) => {
    const messageHash = ethers.utils.solidityKeccak256(["string"], [requestMessage])
    const messageBytes = ethers.utils.arrayify(messageHash);
    const signature = await wallet.signMessage(messageBytes);

    console.log(
        `Signing and responding to request ${requestId}`
    )
    console.log({ message: requestMessage, blocknumber: requestBlocknumber },
        requestId,
        signature);
    const tx = await contract.respondToRequest(
        { message: requestMessage, blocknumber: requestBlocknumber },
        requestId,
        signature
    );

    await tx.wait();
    console.log(`Successfully responded to request!`);
};

const registerOperator = async () => {
    console.log("check")
    const tx1 = await delegationManager.registerAsOperator({
        earningsReceiver: wallet.address,
        delegationApprover: "0x0000000000000000000000000000000000000000",
        stakerOptOutWindowBlocks: 0
    }, "");
    await tx1.wait();
    console.log("Operator registered on EL successfully");

    const salt = ethers.utils.hexlify(ethers.utils.randomBytes(32));
    const expiry = Math.floor(Date.now() / 1000) + 3600; // Example expiry, 1 hour from now

    // Define the output structure
    let operatorSignature = {
        expiry: expiry,
        salt: salt,
        signature: ""
    };

    // Calculate the digest hash using the avsDirectory's method
    const digestHash = await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
        wallet.address,
        contract.address,
        salt,
        expiry
    );

    // Sign the digest hash with the operator's private key
    const signingKey = new ethers.utils.SigningKey(process.env.PRIVATE_KEY!);
    const signature = signingKey.signDigest(digestHash);

    // Encode the signature in the required format
    operatorSignature.signature = ethers.utils.joinSignature(signature);

    const tx2 = await registryContract.registerOperatorWithSignature(
        operatorSignature,
        wallet.address
    );
    await tx2.wait();

    console.log("Operator registered on AVS successfully");
};

const monitorNewRequests = async () => {
    contract.on("MessageRequestCreated", async (id: number, req: any) => {
        console.log(`New request detected with the following message: ${req.message}`);
        await signAndRespondToRequest(id, req.blocknumber, req.message);
    });

    console.log("Monitoring for new requests...");
};

const main = async () => {

    await registerOperator();
    monitorNewRequests().catch((error) => {
        console.error("Error monitoring tasks:", error);
    });
};

main().catch((error) => {
    console.error("Error in main function:", error);
});
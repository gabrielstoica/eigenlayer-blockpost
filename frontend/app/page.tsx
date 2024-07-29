"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAccount, useDisconnect } from "wagmi";
import { styledToast, trimAddress } from "@/lib/utils";
import { Separator } from "@/components/ui/separator";
import { useWeb3Modal } from "@web3modal/wagmi/react";
import { useState } from "react";
import { Icons } from "@/components/ui/icons";
import { ExitIcon, CubeIcon } from "@radix-ui/react-icons";
import { readContract, writeContract, waitForTransactionReceipt } from "@wagmi/core";
import { config } from "@/config";
import { blockpostAVSABI } from "@/lib/abis";
import { BLOCKPOST_AVS_CONTRACT_ADDRESS } from "@/lib/constants";

export default function Home() {
  const { isConnected, address: userAddress } = useAccount();
  const { open } = useWeb3Modal();
  const { disconnect } = useDisconnect();
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [message, setMessage] = useState<string>("");
  const [messageId, setMessageId] = useState<number>(0);

  const handleDisconnect = () => {
    disconnect();
  };

  const handleConnect = async () => {
    setIsLoading(true);
    open();
    setIsLoading(false);
  };

  const onRetrieveMessage = async () => {
    setIsLoading(true);

    try {
      const result = await readContract(config, {
        abi: blockpostAVSABI,
        address: BLOCKPOST_AVS_CONTRACT_ADDRESS,
        account: userAddress,
        functionName: "messages",
        args: [messageId],
      });

      console.log(result);

      // Display a success toast to the user
      styledToast(`Successfully requested message ${messageId}: ${result}`, "success");
    } catch (error) {
      console.log(error);
      styledToast("There was an error. Please try again.", "error");
    } finally {
      setMessageId(0);
      setIsLoading(false);
    }
  };

  const onStoreMessage = async () => {
    setIsLoading(true);

    try {
      const hash = await writeContract(config, {
        abi: blockpostAVSABI,
        address: BLOCKPOST_AVS_CONTRACT_ADDRESS,
        functionName: "createNewRequest",
        args: [message],
      });

      // Wait for transaction to be mined
      const data = await waitForTransactionReceipt(config, { hash });

      // Display a success toast to the user
      styledToast(`You've successfully requested message storage!`, "success");
    } catch (error) {
      console.log(error);
      styledToast("There was an error. Please try again.", "error");
    } finally {
      setMessage("");
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center">
      <Card className="w-full max-w-lg justify-center">
        <CardHeader>
          <CardTitle className="text-2xl">
            {isConnected ? "Store on-chain messages" : "Blockpost EigenLayer AVS"}
          </CardTitle>
          <CardDescription>
            {isConnected
              ? `Connected to ${trimAddress(userAddress)}`
              : "Simple EigenLayer AVS to store and retrieve on-chain messages"}
          </CardDescription>
        </CardHeader>
        <Separator className="mb-6" />
        <CardContent className="grid gap-4">
          {isConnected ? (
            <div className="grid gap-3">
              <div className="grid w-full max-w-sm items-center gap-1.5">
                <Label htmlFor="message">Message</Label>
                <Input
                  type="text"
                  id="message"
                  placeholder="Enter your message"
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                />
                <Button type="button" size="sm" onClick={onStoreMessage} disabled={isLoading}>
                  {isLoading ? (
                    <>
                      <Icons.spinner className="mr-2 h-4 w-4 animate-spin" /> Please wait
                    </>
                  ) : (
                    "Store"
                  )}
                </Button>
              </div>
              <Separator className="my-2" />
              <div className="grid w-full max-w-sm items-center gap-1.5">
                <Label htmlFor="retrieve">Retrieve</Label>
                <Input
                  type="number"
                  id="retrieve"
                  placeholder="Enter message ID to retrieve"
                  value={messageId}
                  onChange={(e) => setMessageId(Number(e.target.value))}
                />
                <Button type="button" size="sm" onClick={onRetrieveMessage} disabled={isLoading}>
                  {isLoading ? (
                    <>
                      <Icons.spinner className="mr-2 h-4 w-4 animate-spin" />
                      Please wait
                    </>
                  ) : (
                    "Retrieve"
                  )}
                </Button>
              </div>

              <Separator className="my-2" />
            </div>
          ) : (
            "Please connect your wallet to access the app"
          )}
        </CardContent>
        <CardFooter className="flex justify-between">
          <Button
            variant={isConnected ? "outline" : "default"}
            type="button"
            disabled={isLoading}
            onClick={isConnected ? handleDisconnect : handleConnect}
          >
            {isLoading ?? <Icons.spinner className="mr-2 h-4 w-4 animate-spin" />}
            {isConnected ? (
              <>
                <ExitIcon className="mr-2 h-4 w-4" />
                Disconnect
              </>
            ) : (
              <>
                <CubeIcon className="mr-2 h-4 w-4" /> Connect your wallet
              </>
            )}
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}

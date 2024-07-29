import type { Metadata } from "next";
import { Inter as FontSans } from "next/font/google";
import "./globals.css";
import { cn } from "@/lib/utils";
import Web3ModalProvider from "@/context";
import { cookieToInitialState } from "wagmi";
import { headers } from "next/headers";
import { config } from "@/config";
import { Toaster } from "react-hot-toast";

const fontSans = FontSans({
  subsets: ["latin"],
  variable: "--font-sans",
});

export const metadata: Metadata = {
  title: "Blockpost EigenLayer",
  description: "Simple EigenLayer AVS to store and retrieve on-chain messages",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const initialState = cookieToInitialState(config, headers().get("cookie"));

  return (
    <html lang="en">
      <body className={cn("min-h-screen bg-background font-sans antialiased", fontSans.variable)}>
        <Toaster position="bottom-left" reverseOrder={false} />
        <Web3ModalProvider initialState={initialState}>{children}</Web3ModalProvider>
      </body>
    </html>
  );
}

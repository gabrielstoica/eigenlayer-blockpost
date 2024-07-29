import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"
import toast from "react-hot-toast";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Helper function used to format an Ethereum wallet address displaying the first and last 5 characters
 *
 * @param address The Ethereum wallet address
 * @returns The formatted address
 */
export const trimAddress = (address: `0x${string}` | undefined) => {
  return address && `${address.substring(0, 5)}...${address.slice(-5)}`;
};

/**
 *
 * @param message The message to display on the toast
 * @param type The type of the toast; can be either {success} or {error}
 */
export function styledToast(message: string, type: string) {
  if (type === "success") {
    toast.success(message);
  } else if (type === "error") {
    toast.error(message);
  }
}
"use client";

import { ReactNode } from "react";
import { WagmiProvider } from "wagmi";
import { http, createConfig } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { defineChain } from "viem";

const queryClient = new QueryClient();

const chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID || 11155111);
const rpcUrl = process.env.NEXT_PUBLIC_RPC_URL || "";

const customChain = defineChain({
    id: chainId,
    name: chainId === 84532 ? "Base Sepolia" : chainId === 11155111 ? "Sepolia" : `Chain ${chainId}`,
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
});

export const wagmiConfig = createConfig({
    chains: [customChain],
    transports: {
        [customChain.id]: http(rpcUrl ? rpcUrl : undefined),
    },
});

export default function Providers({ children }: { children: ReactNode }) {
    return (
        <WagmiProvider config={wagmiConfig}>
            <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
        </WagmiProvider>
    );
}

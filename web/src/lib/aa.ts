// Minimal AA client placeholders for future integration
// We'll implement Etherspot/Skandha bundler RPC and UserOperation packing in M2.

import { encodeFunctionData, type Address } from "viem";

export type AaMode = "disabled" | "enabled";

let aaMode: AaMode = "disabled";

export function setAaMode(mode: AaMode) {
    aaMode = mode;
}

export function getAaMode(): AaMode {
    return aaMode;
}

export type UserOperationRequest = {
    sender: Address;
    nonce: bigint;
    initCode?: `0x${string}`;
    callData: `0x${string}`;
    accountGasLimits: bigint;
    preVerificationGas: bigint;
    gasFees: bigint;
    paymasterAndData?: `0x${string}`;
    signature?: `0x${string}`;
};

export async function sendUserOp(uo: UserOperationRequest): Promise<`0x${string}`> {
    void uo; // avoid unused var warning until implemented
    if (aaMode !== "enabled") throw new Error("AA mode disabled");
    // TODO: implement bundler RPC call
    throw new Error("AA client not yet implemented");
}

export function getAaEnv() {
    return {
        bundlerUrl: process.env.NEXT_PUBLIC_BUNDLER_RPC_URL || "",
        entryPoint: (process.env.NEXT_PUBLIC_ENTRYPOINT_ADDRESS || "") as Address,
        paymaster: (process.env.NEXT_PUBLIC_PAYMASTER_ADDRESS || "") as Address,
        factory: (process.env.NEXT_PUBLIC_SIMPLE_ACCOUNT_FACTORY || "") as Address,
    };
}

// SimpleAccount ABI fragment for execute(address,uint256,bytes)
const SIMPLE_ACCOUNT_ABI = [{
    type: "function",
    name: "execute",
    stateMutability: "payable",
    inputs: [
        { name: "target", type: "address" },
        { name: "value", type: "uint256" },
        { name: "data", type: "bytes" },
    ],
    outputs: [],
}] as const;

export function buildSimpleAccountCallData(params: { account: Address; target: Address; value?: bigint; data: `0x${string}`; }): `0x${string}` {
    const value = params.value ?? 0n;
    return encodeFunctionData({ abi: SIMPLE_ACCOUNT_ABI, functionName: "execute", args: [params.target, value, params.data] });
}

export function buildPaymasterAndData(params: { paymaster: Address; validationGas: bigint; postOpGas: bigint; extraData?: `0x${string}`; }): `0x${string}` {
    const address20 = params.paymaster.toLowerCase();
    const valGas = params.validationGas;
    const poGas = params.postOpGas;
    const enc = `${address20}${toUint128Hex(valGas).slice(2)}${toUint128Hex(poGas).slice(2)}${(params.extraData || "0x").slice(2)}` as `0x${string}`;
    return enc;
}

function toUint128Hex(x: bigint): `0x${string}` {
    const hex = x.toString(16);
    const padded = hex.padStart(32, "0");
    return (`0x${padded}`) as `0x${string}`;
}

export function buildUserOperationPreview(params: {
    account: Address;
    callData: `0x${string}`;
    maxVerificationGas: bigint;
    maxCallGas: bigint;
    postOpGas: bigint;
    preVerificationGas: bigint;
    maxFeePerGas: bigint;
    maxPriorityFeePerGas: bigint;
    paymaster: Address;
}): UserOperationRequest {
    // accountGasLimits packs verification (hi 128) | call (lo 128)
    const accountGasLimits = ((params.maxVerificationGas << 128n) | params.maxCallGas) as bigint;
    // gasFees packs maxPriorityFee (hi 128) | maxFee (lo 128)
    const gasFees = ((params.maxPriorityFeePerGas << 128n) | params.maxFeePerGas) as bigint;
    const paymasterAndData = buildPaymasterAndData({ paymaster: params.paymaster, validationGas: params.maxVerificationGas, postOpGas: params.postOpGas });
    const uo: UserOperationRequest = {
        sender: params.account,
        nonce: 0n,
        initCode: undefined,
        callData: params.callData,
        accountGasLimits,
        preVerificationGas: params.preVerificationGas,
        gasFees,
        paymasterAndData,
        signature: "0x" as `0x${string}`,
    };
    return uo;
}

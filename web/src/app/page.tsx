"use client";

import { useState } from "react";
import { useReadContract } from "wagmi";
import { parseAbi } from "viem";

const budgetAbi = parseAbi([
  "function getBudget(address) view returns (uint128 limitWei, uint128 usedWei, uint32 epochIndex)",
]);

type GetBudgetResult = readonly [bigint, bigint, number];

export default function Home() {
  const [paymaster, setPaymaster] = useState<string>("");
  const [account, setAccount] = useState<string>("");

  const { data, refetch, isFetching, error } = useReadContract({
    abi: budgetAbi,
    address: paymaster as `0x${string}` | undefined,
    functionName: "getBudget",
    args: account ? [account as `0x${string}`] : undefined,
    query: { enabled: false },
  });

  const tuple = data as GetBudgetResult | undefined;
  const limit = tuple?.[0];
  const used = tuple?.[1];
  const epoch = tuple?.[2];

  return (
    <main style={{ padding: 24, maxWidth: 800, margin: "0 auto" }}>
      <h1>DAO Gas Reimbursement</h1>
      <section style={{ marginTop: 24 }}>
        <h2>Check Budget</h2>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input
            placeholder="Paymaster address"
            value={paymaster}
            onChange={(e) => setPaymaster(e.target.value)}
            style={{ flex: 1, minWidth: 320 }}
          />
          <input
            placeholder="Account (smart wallet)"
            value={account}
            onChange={(e) => setAccount(e.target.value)}
            style={{ flex: 1, minWidth: 320 }}
          />
          <button disabled={!paymaster || !account || isFetching} onClick={() => refetch()}>
            {isFetching ? "Loading..." : "Load"}
          </button>
        </div>
        {error && <p style={{ color: "crimson" }}>{String((error as { message?: string })?.message || error)}</p>}
        {tuple && (
          <div style={{ marginTop: 12 }}>
            <div>limitWei: {limit?.toString()}</div>
            <div>usedWei: {used?.toString()}</div>
            <div>epochIndex: {epoch}</div>
          </div>
        )}
      </section>

      <section style={{ marginTop: 32 }}>
        <h2>Demo Actions</h2>
        <p>Coming next: call GovActions.setParam/grantRole via 4337 flow.</p>
      </section>
    </main>
  );
}

"use client";

import { useMemo, useState } from "react";
import { useAccount, useConnect, useDisconnect, useReadContract, useWriteContract } from "wagmi";
import { parseAbi } from "viem";
import { getAaMode, setAaMode } from "@/lib/aa";

const budgetAbi = parseAbi([
  "function getBudget(address) view returns (uint128 limitWei, uint128 usedWei, uint32 epochIndex)",
]);

const govAbi = parseAbi([
  "function setParam(bytes32 key, uint256 value)",
  "function grantRole(address user)",
]);

type GetBudgetResult = readonly [bigint, bigint, number];

export default function Home() {
  const [paymaster, setPaymaster] = useState<string>("");
  const [accountAddr, setAccountAddr] = useState<string>("");
  const [gov, setGov] = useState<string>("");
  const [keyHex, setKeyHex] = useState<string>("0x706172616d");
  const [value, setValue] = useState<string>("1");
  const [roleUser, setRoleUser] = useState<string>("");

  const { connectors, connect, status: connectStatus } = useConnect();
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();

  const { data, refetch, isFetching, error } = useReadContract({
    abi: budgetAbi,
    address: paymaster as `0x${string}` | undefined,
    functionName: "getBudget",
    args: accountAddr ? [accountAddr as `0x${string}`] : undefined,
    query: { enabled: false },
  });

  const { writeContractAsync, status: writeStatus, error: writeError } = useWriteContract();

  const tuple = data as GetBudgetResult | undefined;
  const limit = tuple?.[0];
  const used = tuple?.[1];
  const epoch = tuple?.[2];

  const availableConnectors = useMemo(() => connectors.filter((c) => c.id !== "injected" || c.ready), [connectors]);

  return (
    <main style={{ padding: 24, maxWidth: 900, margin: "0 auto", display: "grid", gap: 24 }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h1>DAO Gas Reimbursement</h1>
        <div>
          {isConnected ? (
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <code>{address}</code>
              <button onClick={() => disconnect()}>Disconnect</button>
            </div>
          ) : (
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              {availableConnectors.map((c) => (
                <button key={c.id} disabled={connectStatus === "pending"} onClick={() => connect({ connector: c })}>
                  Connect {c.name}
                </button>
              ))}
            </div>
          )}
        </div>
      </header>

      <section>
        <h2>Mode</h2>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <span>AA mode:</span>
          <button onClick={() => setAaMode(getAaMode() === "enabled" ? "disabled" : "enabled")}>{getAaMode()}</button>
          <span style={{ opacity: 0.7 }}>(placeholder; direct EOA txs currently)</span>
        </div>
      </section>

      <section>
        <h2>Check Budget</h2>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input placeholder="Paymaster address" value={paymaster} onChange={(e) => setPaymaster(e.target.value)} style={{ flex: 1, minWidth: 320 }} />
          <input placeholder="Account (smart wallet)" value={accountAddr} onChange={(e) => setAccountAddr(e.target.value)} style={{ flex: 1, minWidth: 320 }} />
          <button disabled={!paymaster || !accountAddr || isFetching} onClick={() => refetch()}>
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

      <section>
        <h2>GovActions (direct tx for now)</h2>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input placeholder="GovActions address" value={gov} onChange={(e) => setGov(e.target.value)} style={{ flex: 1, minWidth: 320 }} />
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 8 }}>
          <input placeholder="key (bytes32 hex)" value={keyHex} onChange={(e) => setKeyHex(e.target.value)} style={{ minWidth: 240 }} />
          <input placeholder="value (uint256)" value={value} onChange={(e) => setValue(e.target.value)} style={{ minWidth: 160 }} />
          <button
            disabled={!isConnected || !gov}
            onClick={async () => {
              await writeContractAsync({
                address: gov as `0x${string}`,
                abi: govAbi,
                functionName: "setParam",
                args: [keyHex as `0x${string}`, BigInt(value || "0")],
              });
            }}
          >
            setParam
          </button>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 8 }}>
          <input placeholder="user address" value={roleUser} onChange={(e) => setRoleUser(e.target.value)} style={{ minWidth: 320 }} />
          <button
            disabled={!isConnected || !gov || !roleUser}
            onClick={async () => {
              await writeContractAsync({
                address: gov as `0x${string}`,
                abi: govAbi,
                functionName: "grantRole",
                args: [roleUser as `0x${string}`],
              });
            }}
          >
            grantRole
          </button>
        </div>
        {writeError && <p style={{ color: "crimson" }}>{String((writeError as { message?: string })?.message || writeError)}</p>}
        <p style={{ opacity: 0.7 }}>AA integration will replace these with sponsored ops in M2.</p>
      </section>
    </main>
  );
}

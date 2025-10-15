"use client";

import { useMemo, useState } from "react";
import { useAccount, useConnect, useDisconnect, useReadContract, useWriteContract } from "wagmi";
import { parseAbi, encodeFunctionData, type Address } from "viem";
import { getAaMode, setAaMode, buildSimpleAccountCallData, buildUserOperationPreview, sendUserOp, getAaEnv, type UserOperationRequest } from "../lib/aa";

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
  const [aaPreview, setAaPreview] = useState<UserOperationRequest | null>(null);
  const [aaError, setAaError] = useState<string>("");

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

  const { writeContractAsync, error: writeError } = useWriteContract();

  const tuple = data as GetBudgetResult | undefined;
  const limit = tuple?.[0];
  const used = tuple?.[1];
  const epoch = tuple?.[2];

  const availableConnectors = useMemo(() => connectors.filter((c) => c.id !== "injected" || c.ready), [connectors]);

  const env = getAaEnv();
  const demoMode = !process.env.NEXT_PUBLIC_RPC_URL;

  async function buildAaForGovCall(fn: "setParam" | "grantRole") {
    setAaError("");
    setAaPreview(null);
    try {
      if (!env.entryPoint || !env.paymaster) throw new Error("Missing ENTRYPOINT/PAYMASTER env");
      if (!accountAddr) throw new Error("Set SimpleAccount address in 'Account (smart wallet)'");
      if (!gov) throw new Error("Set GovActions address");

      let innerData: `0x${string}`;
      if (fn === "setParam") {
        innerData = encodeFunctionData({ abi: govAbi, functionName: "setParam", args: [keyHex as `0x${string}`, BigInt(value || "0")] });
      } else {
        innerData = encodeFunctionData({ abi: govAbi, functionName: "grantRole", args: [roleUser as `0x${string}`] });
      }

      const callData = buildSimpleAccountCallData({ account: accountAddr as Address, target: gov as Address, value: 0n, data: innerData });

      const uo = buildUserOperationPreview({
        account: accountAddr as Address,
        callData,
        maxVerificationGas: 100_000n,
        maxCallGas: 500_000n,
        postOpGas: 80_000n,
        preVerificationGas: 50_000n,
        maxFeePerGas: 20_000_000_000n,
        maxPriorityFeePerGas: 1_000_000_000n,
        paymaster: env.paymaster,
      });
      setAaPreview(uo);
    } catch (e) {
      const err = e as { message?: string };
      setAaError(err?.message || String(e));
    }
  }

  async function attemptSendAa() {
    setAaError("");
    try {
      if (!aaPreview) throw new Error("Build preview first");
      const hash = await sendUserOp(aaPreview);
      alert(`Submitted userOp: ${hash}`);
    } catch (e) {
      const err = e as { message?: string };
      setAaError(err?.message || String(e));
    }
  }

  return (
    <main className="grid">
      <header className="header">
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <img src="/logo.jpg" alt="logo" width={36} height={36} style={{ borderRadius: 8, border: "1px solid var(--border)" }} />
          <h1>DAO Gas Reimbursement</h1>
          {demoMode && <span className="badge">Demo Mode</span>}
        </div>
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

      <section className="card">
        <div className="card-header"><h2>Overview</h2><span className="subtle">Budget & usage</span></div>
        <div className="kpi" style={{ marginTop: 12 }}>
          <div>
            <div style={{ opacity: 0.6, fontSize: 12 }}>Monthly Limit (wei)</div>
            <div className="mono" style={{ fontSize: 18, marginTop: 6 }}>{limit?.toString() ?? <div className="skeleton" />}</div>
          </div>
          <div>
            <div style={{ opacity: 0.6, fontSize: 12 }}>Used (wei)</div>
            <div className="mono" style={{ fontSize: 18, marginTop: 6 }}>{used?.toString() ?? <div className="skeleton" />}</div>
          </div>
          <div>
            <div style={{ opacity: 0.6, fontSize: 12 }}>Epoch</div>
            <div className="mono" style={{ fontSize: 18, marginTop: 6 }}>{epoch ?? <div className="skeleton" />}</div>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="card-header"><h2>Mode</h2><span className="chip">AA experimental</span></div>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <span>AA mode:</span>
          <button className="cta" onClick={() => setAaMode(getAaMode() === "enabled" ? "disabled" : "enabled")}>{getAaMode()}</button>
          <span style={{ opacity: 0.7 }}>Use preview without bundler; send coming soon.</span>
        </div>
      </section>

      <section className="card">
        <div className="card-header"><h2>Check Budget</h2><span className="subtle">Reads from Paymaster</span></div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input placeholder="Paymaster address" value={paymaster} onChange={(e) => setPaymaster(e.target.value)} style={{ flex: 1, minWidth: 320 }} />
          <input placeholder="Account (smart wallet)" value={accountAddr} onChange={(e) => setAccountAddr(e.target.value)} style={{ flex: 1, minWidth: 320 }} />
          <button disabled={!paymaster || !accountAddr || isFetching} onClick={() => refetch()}>
            {isFetching ? "Loading..." : "Load"}
          </button>
        </div>
        {error && <p style={{ color: "var(--danger)" }}>{String((error as { message?: string })?.message || error)}</p>}
      </section>

      <section className="card">
        <div className="card-header"><h2>GovActions</h2><span className="subtle">Direct EOA calls for demo</span></div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input placeholder="GovActions address" value={gov} onChange={(e) => setGov(e.target.value)} style={{ flex: 1, minWidth: 320 }} />
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 8 }}>
          <input placeholder="key (bytes32 hex)" value={keyHex} onChange={(e) => setKeyHex(e.target.value)} style={{ minWidth: 240 }} />
          <input placeholder="value (uint256)" value={value} onChange={(e) => setValue(e.target.value)} style={{ minWidth: 160 }} />
          <button disabled={!isConnected || !gov} onClick={async () => {
            await writeContractAsync({ address: gov as `0x${string}`, abi: govAbi, functionName: "setParam", args: [keyHex as `0x${string}`, BigInt(value || "0")] });
          }}>setParam</button>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 8 }}>
          <input placeholder="user address" value={roleUser} onChange={(e) => setRoleUser(e.target.value)} style={{ minWidth: 320 }} />
          <button disabled={!isConnected || !gov || !roleUser} onClick={async () => {
            await writeContractAsync({ address: gov as `0x${string}`, abi: govAbi, functionName: "grantRole", args: [roleUser as `0x${string}`] });
          }}>grantRole</button>
        </div>
        {writeError && <p style={{ color: "var(--danger)" }}>{String((writeError as { message?: string })?.message || writeError)}</p>}
      </section>

      <section className="card">
        <div className="card-header"><h2>AA Preview</h2><span className="subtle">Unsigned userOp</span></div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <button className="cta" onClick={() => buildAaForGovCall("setParam")}>Build AA setParam</button>
          <button className="cta" onClick={() => buildAaForGovCall("grantRole")}>Build AA grantRole</button>
          <button onClick={attemptSendAa} disabled={!aaPreview}>Attempt send</button>
        </div>
        {aaError && <p style={{ color: "var(--danger)" }}>{aaError}</p>}
        {aaPreview && (
          <pre style={{ marginTop: 8, padding: 12, background: "#0b1220", color: "#cbd5e1", overflowX: "auto", borderRadius: 8, border: "1px solid var(--border)" }}>
            {JSON.stringify(aaPreview, null, 2)}
          </pre>
        )}
      </section>

      <footer className="footer">
        <span>Built by David Seibold · </span>
        <a href="https://github.com/PenneconDavid/DAO-Gas-Reimbursement-Paymaster" target="_blank" rel="noreferrer" style={{ color: "#93c5fd" }}>GitHub</a>
      </footer>
    </main>
  );
}

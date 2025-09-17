# Security Notes

## Scope & Assumptions
- Protocol: ERC-4337 EntryPoint v0.8 with a verifying paymaster.
- Trust: The ADMIN/PAUSER is a trusted role (recommended: multisig). Bundlers and RPCs are out of scope but must be reputable.
- Funds: ETH staked/deposited in EntryPoint by the paymaster; withdrawals controlled by ADMIN.

## Admin & Governance Powers
- Set per-sender budgets and global monthly cap.
- Update safety caps (verification/call/postOp gas, fee caps, maxWeiPerOp).
- Pause/unpause sponsorship.
- Stake/deposit/withdraw funds and withdraw stake after unlock.
- Configure optional ReceiptNFT and SimpleAccount factory.

## Risks & Mitigations
- Griefing via large verification/postOp gas: enforce caps; pause on anomalies.
- Budget traversal at epoch edges: lazy month rollover; fuzz/invariant tests on date math.
- High gas price spikes draining budget: absolute + basefee-multiplier fee caps; per-op maxWeiPerOp.
- Sponsoring arbitrary targets: MVP restricts by sender only; optional target parsing in future.
- Self-sponsorship loops/recursion: initCode factory allowlist; explicit EntryPoint-only hooks.
- DoS on paymaster: pausability; simple validation; avoid heavy external calls; per-op caps.

## Reentrancy & External Calls
- No external state-changing calls in validation; postOp does accounting and optional ReceiptNFT mint.
- Receipt minting is optional and should be sized to gas caps; disable or increase caps if needed.

## Operational Guidance
- Monitor deposit level and failure rates; top-up proactively.
- Rotate/administer roles via multisig; avoid EOAs in production.
- Maintain incident response: pause, diagnose, unpause or migrate.

## Static Analysis & Testing
- Unit/integration tests cover budgets, caps, rollover, receipts.
- Recommended: fuzz and invariants (epoch edges, underflow, cap enforcement).
- Slither and Solhint run in CI; address warnings before release.

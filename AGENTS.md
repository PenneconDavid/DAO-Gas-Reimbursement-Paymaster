# Agent Instructions — DAO Gas Reimbursement Paymaster

## Project

- **Name:** DAO-Gas-Reimbursement-Paymaster
- **Purpose:** ERC-4337 DAO gas reimbursement paymaster with budgets, caps, and demo dapp
- **Stack:** Solidity/Foundry, Next.js 15, wagmi/viem

## Dev servers

- **Web demo:** `cd web && npm run dev` → http://localhost:3000
- **Contracts:** `forge build`, `forge test` from contracts directory (see README)

## Shared config

- **Skills:** `.agents/skills/` → [cursor-skills](https://github.com/PenneconDavid/cursor-skills)
- **Rules:** `.cursor/rules/` → [cursor-rules](https://github.com/PenneconDavid/cursor-rules)
- **Connections:** maintain `ConnectionGuide.txt` at repo root (create when adding endpoints)

## Conventions

- Web AA send flow is preview-only — do not assume production account abstraction without checking README.
- Tier 2 UI skills apply to the `web/` Next.js app.
- Ask before installing Foundry deps or npm packages.

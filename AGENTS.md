# Agent Instructions — DAO Gas Reimbursement Paymaster

## Project

- **Name:** DAO-Gas-Reimbursement-Paymaster
- **Purpose:** ERC-4337 DAO gas reimbursement paymaster with budgets, caps, and demo dapp
- **Stack:** Solidity/Foundry, Next.js 15, wagmi/viem

## Dev servers

- **Web demo:** `cd web && npm run dev` → http://localhost:3000
- **Contracts:** `forge build`, `forge test` from contracts directory (see README)

## Commands

| Task | Command |
|------|---------|
| Contracts build | `forge build` |
| Contracts test | `forge test` |
| Solidity lint | `npm run solhint` (repo root) |
| Web install | `cd web && npm install` |
| Web dev server | `cd web && npm run dev` → http://localhost:3000 |
| Web typecheck | `cd web && npx tsc --noEmit` |
| Web lint | `cd web && npm run lint` |
| Web build | `cd web && npm run build` |

A `Makefile` at the root wraps common targets; read it before adding new ones.

## Definition of done

- Contract changes: `forge build`, `forge test`, and `npm run solhint` pass.
- Web changes: typecheck, lint, and build pass; `visual-qa-testing` on the changed page.
- `ConnectionGuide.txt` updated if any RPC endpoint, contract address, or route changed.
- Never broadcast a deployment script without asking.

## Shared config

- **Skills:** `.agents/skills/` → [cursor-skills](https://github.com/PenneconDavid/cursor-skills)
- **Rules:** `.cursor/rules/` → [cursor-rules](https://github.com/PenneconDavid/cursor-rules)
- **Connections:** maintain `ConnectionGuide.txt` at repo root (create when adding endpoints)

## Conventions

- Web AA send flow is preview-only — do not assume production account abstraction without checking README.
- Tier 2 UI skills apply to the `web/` Next.js app.
- Ask before installing Foundry deps or npm packages.

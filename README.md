# AgentPay

**Pay, escrow and invoice BNB by Agent ID handle on BNB Chain.**

Built for the **Binance Wallet × BNB Chain Agent ID Hackathon** (Nov–Dec 2026).

AgentPay turns the Agent ID (`*.ai`, non-transferable SPACE ID Agent ID on BSC)
into a payment identity: you send, escrow or invoice value **to a handle**, and
the contract resolves handle → wallet **on-chain, inside every transaction**,
using the official Agent ID registry — no address book, no off-chain database,
no admin keys, no fees.

- **Live app:** https://riyan3110.github.io/agentpay/
- **Contract (BSC mainnet):** [`0xebfB41E4843734EfE489587bEE11B34a510fd001`](https://bscscan.com/address/0xebfb41e4843734efe489587bee11b34a510fd001)
- **Agent ID registry (official):** [`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`](https://bscscan.com/address/0x60b9262456de011f7d15a54cdd8c48baaa8b022f)

## How Agent ID is used (core, not decoration)

| Flow | On-chain use of the registry |
|---|---|
| **Pay by handle** | `pay(handle, memo)` calls `ownerOfHandle(handle)` inside the tx and forwards BNB to the resolved wallet |
| **Escrow to a handle** | `lockEscrow(handle)` earmarks BNB to the handle; `claimEscrow()` reverse-resolves `handleOf(msg.sender)` and only the wallet permanently bound to that handle can claim — soulbound = unstealable |
| **Invoices** | `createInvoice` is signed by the payee's Agent ID wallet (`handleOf(msg.sender)`); `payInvoice(id)` re-resolves the payee at payment time |
| **Directory** | `join()` requires `balanceOf(msg.sender) > 0` on the registry — Agent ID holders only |

Because Agent IDs are **non-transferable and permanent**, handle-based escrow
rights cannot be sold, faked, or transferred — the registry itself is the
membership database and the claim authority.

## Safety / red-line compliance

- **No owner, no admin functions.** Once deployed, nobody can pause, upgrade,
  mint, or withdraw user funds. All value movement is either (a) a direct
  user-initiated forward visible in the caller's transaction, or (b) a claim by
  the identity holder themselves.
- **No approvals, no allowance requests, no fee on any path.**
- **No credential collection, no QR/pairing login, no session storage.**
- **No promises of returns; no Binance/BNB brand impersonation.**
- Frontend shows a risk notice; all transactions are confirmed by the user in
  their own wallet.

## Build

```bash
npm install
node compile.js   # writes out_AgentPay_bytecode.hex + out_AgentPay_abi.json
```

Solidity 0.8.26, optimizer 200 runs, no external dependencies. The contract was
deployed through the canonical CREATE2 factory
(`0x4e59b44847b379578588920cA78FbF26c0B4956C`, salt `0`) so its address is
deterministic from the init code.

## License

MIT

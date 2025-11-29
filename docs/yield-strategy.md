# Yield Strategy Module

This document explains the Aave-integrated yield layer introduced on the `feature/yield-strategy` branch. It covers the motivation, architecture, storage layout, key entrypoints, and execution flow so contributors can reason about system behaviour and safely extend it.

## Goals

- **Productive collateral** – Deploy a configurable slice of a user's idle collateral into an external yield source (Aave-compatible pool) without breaking liquidity guarantees.
- **Interest offset** – Return most of the earned yield to borrowers so it can offset loan interest/penalties, while reserving a protocol fee share.
- **Pluggable control** – Security council can enable, tune, or pause per-collateral strategies via diamond facets.

## High-Level Architecture

```
ProtocolFacet.depositCollateral()
  └─ LibYieldStrategy._rebalancePosition()
       ├─ computes target allocation based on config
       ├─ supplies/withdraws via IAavePool
       └─ updates per-position principal + global totals

YieldStrategyFacet.claimYield()
  └─ LibYieldStrategy._claimYield()
       ├─ accrues global yield since last checkpoint
       ├─ settles pending user share
       ├─ redeems underlying from Aave
       └─ transfers funds to borrower
```

### Components Added

| File | Purpose |
|------|---------|
| `contracts/models/Yield.sol` | Declares `YieldStrategyConfig` and `YieldPosition` structs persisted in storage. |
| `contracts/libraries/LibYieldStrategy.sol` | Core logic for allocation, redemption, yield accrual, accounting, and guardrails. |
| `contracts/facets/YieldStrategyFacet.sol` | Diamond facet exposing admin/user entrypoints to configure tokens, pause, claim, and harvest. |
| `contracts/mocks/MockAavePool.sol` | Minimal Aave-like pool for deterministic Foundry tests. |
| `test/YieldStrategy.t.sol` | Integration tests covering allocation, withdrawal unwind, borrower claims, and protocol harvest. |
| `README.md` & `docs/yield-strategy.md` | Documentation for operators and contributors. |

Existing modules (`LibAppStorage`, `LibProtocol`, `LibLiquidation`, events/errors) were extended to plug the new flow into deposit/withdraw/liquidation paths.

## Storage Additions

Located in `LibAppStorage.StorageLayout`:

- `mapping(address => YieldStrategyConfig) s_yieldConfigs` – Per-collateral strategy parameters.
- `mapping(uint256 => mapping(address => YieldPosition)) s_positionYield` – Per-position principal deployed + accrued yield per token.
- `mapping(address => bool) s_yieldApprovals` – Tracks `IERC20.approve` calls to the configured pool (avoid repeated approvals).

### Structs

```solidity
struct YieldStrategyConfig {
    bool enabled;            // strategy activated for this token
    bool paused;             // guardrail toggle
    address aavePool;        // target IAavePool implementation
    address aToken;          // interest-bearing token address
    uint16 allocationBps;    // portion of collateral to deploy (0-10000)
    uint16 protocolShareBps; // fee share retained by protocol (0-10000)
    uint256 totalPrincipal;  // sum of deployed user collateral
    uint256 accYieldPerPrincipalRay; // cumulative user yield per unit principal (1e27 precision)
    uint256 protocolAccrued; // pending protocol fees (in underlying)
    uint256 lastRecordedBalance; // last observed aToken balance for delta calculations
}

struct YieldPosition {
    uint256 principal;                    // amount of this position's collateral deployed into yield
    uint256 userAccrued;                  // claimable underlying belonging to borrower
    uint256 entryAccYieldPerPrincipalRay; // accumulator snapshot when principal was last updated
}
```

## Library Responsibilities (`LibYieldStrategy`)

1. **Configuration**
   - `_configureYieldToken` validates parameters, registers pool + aToken, resets accumulators, and emits `YieldTokenConfigured`.
   - `_setYieldPause` toggles the strategy for emergency stops.

2. **Allocation & Rebalancing**
   - `_rebalancePosition` computes target allocation = `collateral * allocationBps / 10_000` and supplies/withdraws delta via `_supply` / `_withdraw`.
   - `_ensureSufficientIdle` forces withdrawals before collateral leaves the diamond (withdraws/liquidations).

3. **Yield Accrual**
   - `_accrueYield` snapshots current aToken balance, distributes delta between protocol and users, updates `accYieldPerPrincipalRay`, and stores `protocolAccrued`.
   - `_settlePositionYield` applies the accumulator delta to a position, moving pending rewards into `userAccrued`.

4. **User + Protocol Claims**
   - `_claimYield` settles user share, redeems underlying from the pool, and transfers to recipient.
   - `_harvestProtocolYield` lets the security council redeem the protocol fee share.
   - `_pendingYield` offers a view helper combining stored accruals with not-yet-settled growth.

5. **Safety**
   - Guardrails ensure only ERC20 collateral participates, caps basis points at 10_000, and revert with descriptive errors (`YIELD_*`).
   - Approvals to Aave pools are issued once per token and reused.

## Facet API (`YieldStrategyFacet.sol`)

| Function | Role |
|----------|------|
| `configureYieldToken(token, pool, aToken, allocationBps, protocolShareBps)` | Security council config of per-token strategy parameters. |
| `setYieldPause(token, paused)` | Emergency pause/resume. |
| `rebalancePosition(token)` | Optional manual rebalance (typically automatic via hooks). |
| `claimYield(token, amount, recipient)` | Borrower claims their share (amount=0 → all). |
| `harvestProtocolYield(token, recipient, amount)` | Security council harvests protocol share. |
| `getYieldConfig(token)` | View helper returning current config. |
| `getYieldPosition(user, token)` | Returns per-position principal + accrued amounts. |
| `getPendingYield(token)` | View-only aggregate of borrower's pending rewards. |

All admin-modifying methods use `onlySecurityCouncil` (contract owner from `LibDiamond`).

## Execution Flow

1. **Deposit Collateral**
   - `ProtocolFacet.depositCollateral` dd> `LibProtocol._depositCollateral`
   - After transferring tokens, `LibYieldStrategy._rebalancePosition` runs to push the configured percentage into Aave.
   - Emits `YieldAllocated` when capital is deployed.

2. **Withdraw / Liquidation**
   - Prior to sending collateral out, protocol calls `_rebalancePosition` and `_ensureSufficientIdle` to unlock enough idle funds from Aave.
   - Ensures standard withdrawals and liquidations have required liquidity without manual intervention.

3. **Yield Accrual + Claiming**
   - Any strategy interaction triggers `_accrueYield`, which splits growth:
     - `protocolShare = delta * protocolShareBps / 10_000`
     - `userShare = delta - protocolShare`
   - Borrowers call `claimYield` anytime; protocol uses `harvestProtocolYield` when ready.

## Testing & Tooling

- `contracts/mocks/MockAavePool.sol` emulates Aave's `supply`/`withdraw` functions and allows `simulateYield` to mint extra aTokens + underlying.
- `test/YieldStrategy.t.sol` covers allocation upon deposit, rebalancing on withdraw, borrower claim flow, and protocol harvest.
- All existing Foundry test suites pass (`forge test`), confirming no regressions across collateral, vault, liquidation, or protocol logic.

## Operational Checklist

1. Deploy new facet + library (follow diamond upgrade process).
2. Security council config for each collateral token:
   ```solidity
   yieldStrategy.configureYieldToken(
       token,
       aavePool,
       aToken,
       /* allocationBps */ 4000,
       /* protocolShareBps */ 1500
   );
   ```
3. Monitor `YieldAccrued`, `YieldAllocated`, `YieldReleased`, and `ProtocolYieldHarvested` events for accounting.
4. In emergencies, toggle `setYieldPause(token, true)` to stop new allocations while keeping existing collateral withdrawable.

## Future Extensions

- Support multiple strategies per token (e.g., diversify across venues).
- Allow borrowers to apply yield directly toward outstanding debt (auto-repay hook).
- Add strategy-specific risk parameters (max deposit cap, time-weighted rebalances) to guard against pool liquidity crunches.

This document should be kept in sync with contract changes so new contributors understand how yield-bearing collateral flows through the diamond architecture.

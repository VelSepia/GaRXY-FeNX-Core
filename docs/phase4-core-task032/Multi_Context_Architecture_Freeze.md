# Phase4-Core Task032 Multi-context Architecture Freeze

## Scope and baseline

- Branch: `original-personal-core`
- Baseline: `353b1490a6fe81e3eaa482b662b7b637619f3c89`
- DataBus maximum: 2,048 unique keys
- EngineManager maximum: 256 registrations
- Trading decisions, thresholds, entry, exit, execution, recovery, and health contracts are unchanged.

This document freezes the supported multi-context architecture after retiring the
Task025 migration aliases. Context-local DataBus storage has one schema only:
`namespace.symbol.timeframe.field`. System-wide values use the formal
`namespace.field` schema or an explicitly owned typed store.

## Frozen layers and ownership

| Layer | Frozen owner and contract |
|---|---|
| Context identity | `SRuntimeContextId` owns `symbol + timeframe`; `SRuntimeContextConfig` adds role, trade permission, required/optional status, and magic. |
| Runtime registry | `CRuntimeContextRegistry` owns context creation, uniqueness, Primary selection, layer preparation, registration order, and capacity preflight. |
| Analysis | Each `CRuntimeContext` owns Volatility, Range, Trend, Market State, Environment, and Market Selection instances. Analysis snapshots are keyed by the complete context identity in `CCommonSnapshotStore`. |
| Global portfolio | Pair Ranking and Capital Allocation evaluate the typed context set and publish one `CGlobalPortfolioSnapshotStore` result plus canonical per-context summaries. |
| Decision / safety | Trading Style, Strategy Selection, Standby, Risk, Confidence, and Decision Score are context-bound. Typed snapshots retain context and source sequence identities. Global risk remains an aggregate observer. |
| Execution / position | Each supported context has an execution infrastructure identity. Orders flow only through `COrderExecutor`; `CPositionManager`, `CPositionOwnershipArbiter`, and `CPositionLifecycleRegistry` own position selection, exclusivity, and lifecycle state. |
| Recovery / health | Recovery and Health are context-bound observers. Entry Resume uses the same context recovery sequence. `CGlobalHealthAggregateStore` is read-only aggregate state and has no trading authority. |
| Global aggregates | Portfolio, Risk, and Health aggregates are formally global typed stores/engines. They do not publish context aliases. |

## Identity and routing invariants

- Sequence identity is owned by the snapshot/lifecycle store that creates the
  sequence; consumers retain the source sequence and context identity.
- Position ownership is `context + magic + position ticket`, with the arbiter
  preventing competing owners for the same symbol.
- Transaction routing priority is lifecycle owner, then `symbol + magic`, then
  position ownership. Unknown or ambiguous transactions are not dispatched.
- Magic is supplied by `SRuntimeContextConfig`, validated before registration,
  and applied by `CExecutionEngine`, `CPositionManager`, and `COrderExecutor`.
- Secondary contexts whose strategy does not support that context remain
  analysis-only and cannot submit or close Primary orders.

## DataBus and snapshot freeze

- Canonical context write/read: `SetContextText` / `TryGetContextText`.
- Formal global write/read: `SetGlobalText` / `TryGetGlobalText`.
- A context-bound EngineManager view routes established engine field tokens
  directly to the active canonical context key; it creates no alias and performs
  no fallback read.
- Stored keys with the retired three-segment schema are prohibited and audited.
- Legacy write attempts, read attempts, stored alias keys, invalid schema keys,
  wrong-context access, and wrong-timeframe access must remain zero.
- CommonEnvironment's former 32-field DataBus shadow had zero consumers. The
  typed `SEnvironmentSnapshot` in `CCommonSnapshotStore` is its sole owner, so
  the shadow namespace/field definitions and publication were retired.

## Capacity freeze

Measured Task032 real-runtime results:

| Contexts | DataBus used | Remaining | Spare | Engines |
|---:|---:|---:|---:|---:|
| 1 | 177 | 1,871 | 91.36% | 25 |
| 4 | 708 | 1,340 | 65.43% | 70 |
| 5 | 885 | 1,163 | 56.79% | 85 |

The observed model is 177 DataBus entries per context and `15 * contexts + 10`
EngineManager registrations. Calculated planning points:

| Contexts | DataBus projected | Spare | Engines projected | 30% DataBus spare |
|---:|---:|---:|---:|---:|
| 8 | 1,416 | 30.86% | 130 | PASS |
| 10 | 1,770 | 13.57% | 160 | FAIL |

The frozen production requirement is five contexts, which retains more than the
required 30% DataBus spare and ample EngineManager headroom. Eight contexts are
the largest calculated configuration that preserves the same 30% DataBus reserve.
Ten contexts fit the hard limits but are not approved for production because the
reserve falls below 30%; adding ten-context support requires a separate capacity
decision rather than silently weakening this contract.

## Validation freeze

- Build: main `0 errors / 1 known warning`; current and updated Harness sources
  `0 errors / 0 warnings`.
- Task032 isolation: 11/11 PASS.
- Real runtime: 1 / 4 / 5 contexts PASS.
- Five-context DataBus spare: 56.79%; EngineManager: 85/256.
- Legacy write/read/fallback/schema: 0.
- Context collision, wrong-context, wrong-timeframe: 0.
- Data Leak, Trade Leak, Runtime Error: 0.
- 2021-01-01 through 2025-12-31 USDJPY H1 regression: PASS.
  - 464 trade records, 928 order rows, and 929 deal rows are exactly equal.
  - 31,283 Primary state transitions are exactly equal.
  - Router 3,636/3,636 and lifecycle 464/464 are exactly equal.
  - Entry, Exit, Execution, Task007, all required summary contracts, Recovery,
    and Health are exactly equal; rejects, retries, leaks, and runtime errors are zero.

The retired single-context PairRanking/CapitalAllocation path no longer emits its
diagnostic-only telemetry. The authoritative canonical portfolio path produced
0.01-point rounding differences in 617 non-executed Task011 gate telemetry rows;
the Task011 summary, gate outcomes, entry events, trades, orders, deals, state
transitions, and all specified regression contracts remain exactly equal. These
diagnostic rows are recorded as an expected observability change, not a trading
contract change.

This freeze may be changed only by a separately reviewed task with explicit
capacity, ownership, schema, and regression evidence.

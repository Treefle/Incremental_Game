# Tools Feature Completion Plan

## Goal
Finish the settler tools feature so tools are a complete gameplay system, not just manual stat toggles.

## Current Status Summary
Implemented now:
- Tool types exist (Hand, Axe, Pick, Scythe).
- Per-settler tool assignment exists.
- Harvest multipliers use tool type.
- Hover UI shows equipped tool and effect.
- Tool inventory state exists in runtime state.
- Per-settler tool loadout and mode persistence exists (`user://tool_state.json`).
- Backward-safe migration logic for legacy/partial tool-state snapshots exists.

Missing for completion:
- Tool economy (crafting/procurement costs and stock).
- Auto-assignment behavior tied to jobs.
- Combat integration for tools.
- Balance pass and performance checks at high settler counts.

---

## Scope Definition
A completed tool system should include:
1. Tool inventory and production loop.
2. Manual equip and optional auto-equip policy.
3. Harvest and combat impact.
4. Full persistence.
5. UI feedback for availability, shortages, and assignment rules.

---

## Implementation Checklist

## Phase 1 - Data Model and Persistence
- [x] Add global tool inventory dictionary in main game state:
  - hand (infinite/default), axe, pick, scythe counts.
- [x] Add per-settler tool loadout persistence serialization.
- [x] Add version-safe migration for old saves without tool fields.
- [x] Ensure new settlers receive default loadout behavior.

Acceptance:
- Saving and loading preserves inventory and each settler's equipped tool.
- Old saves load without crash and initialize sensible defaults.

## Phase 2 - Tool Economy
- [x] Add crafting/refining recipes for axe, pick, scythe (likely lumber + metal).
- [x] Add production entry points (workshop/refinery or dedicated crafting action).
- [x] Prevent equip when inventory is insufficient.
- [x] Return tool to inventory when unequipped or settler dies (if applicable).
- [x] Add UI panel/row showing tool stock and craft buttons.

Acceptance:
- Tool count changes correctly when crafting/equipping/unequipping.
- No negative inventory or duping exploit.

## Phase 3 - Assignment Rules
- [x] Add auto-equip by active job:
  - lumber -> axe
  - stone/metal mining -> pick
  - farm/forage -> scythe
  - fallback -> hand
- [x] Keep manual override mode per settler (Auto vs Locked).
- [x] On job change, auto-mode settlers update tool instantly (or next think tick).
- [x] Show current mode in hover panel.

Acceptance:
- Auto settlers always converge to role-appropriate tools when available.
- Locked settlers keep manual loadout through job changes.

## Phase 4 - Combat Integration
- [x] Define tool combat modifiers (damage, speed, defense, crit, etc.).
- [x] Apply modifiers in combat calculations.
- [x] Keep weapon system primary and tool modifiers secondary.
- [x] Add combat log text to confirm tool effects are active.

Acceptance:
- Same weapon, different tools produce measurable combat differences.
- No NaN/negative cooldown edge cases.

## Phase 5 - UX and Feedback
- [x] Show shortage warnings when requested tool not available.
- [x] Show expected benefit tooltip per job with equipped tool.
- [x] Add quick actions: equip all by role, clear overrides, rebalance tools.
- [x] Update tutorial/help text for tool workflow.

Acceptance:
- Player can understand and resolve tool shortages from UI alone.

## Phase 6 - Balance and Performance
- [x] Tune multipliers so tools are meaningful but not mandatory too early.
- [ ] Validate dawn behavior with hundreds/thousands of settlers.
- [x] Ensure assignment logic is budgeted and does not create frame spikes.
- [ ] Run stress scenario for several in-game days.

Validation note:
- Runtime stress validation is pending because no Godot executable was available in PATH or common install paths in this environment.

Acceptance:
- Stable frame pacing during morning dispatch.
- No long-term simulation drift or assignment thrash.

---

## Suggested Data Structures

Tool stock:
- `tool_inventory := {"axe": int, "pick": int, "scythe": int}`

Settler metadata:
- `settler_tool_mode[index] = "auto" | "locked"`
- `settler_tools[index] = TOOL_*`

Optional derived counters:
- `tool_assigned_counts := {"axe": int, "pick": int, "scythe": int}`

---

## File-Level Work Map
- `scripts/main.gd`
  - state fields, save/load migration, UI, equip flows, assignment logic
- `scripts/managers/settler_manager.gd`
  - add persistent arrays for tool mode if centralized here
- `scripts/systems/settler_decision_system.gd`
  - optional hook for auto-equip timing when state/job changes
- `scripts/systems/combat_system.gd`
  - integrate tool modifiers into damage/cooldown/defense

---

## Test Matrix

Functional:
- [ ] Equip/unequip with and without stock.
- [ ] Auto mode picks valid tools per job.
- [ ] Locked mode persists through job changes.
- [ ] Save/reload preserves all tool state.

Economy:
- [ ] Crafting consumes correct resources and increments stock.
- [ ] No negative stock under rapid UI spam.

Combat:
- [ ] Tool modifiers alter expected outcomes.
- [ ] Combat remains stable with mixed weapon/tool sets.

Performance:
- [ ] 500+ settlers morning dispatch remains stable.
- [ ] Multi-day simulation does not degrade due to reassignment churn.

---

## Definition of Done
The tools feature is complete when:
- Tools are produced/consumed through economy.
- Settlers can run Auto or Locked tool modes.
- Tool effects apply in both harvesting and combat.
- State is fully saved/loaded and backward compatible.
- UI communicates stock, assignment, and shortages clearly.
- High-population simulation stays performant.

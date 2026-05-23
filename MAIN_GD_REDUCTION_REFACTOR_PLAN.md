# main.gd Reduction Refactor Plan

Current state:
- `scripts/main.gd`: 5779 lines
- Orchestrator plus implementation are mixed together.
- Several systems exist (`settler_decision_system`, `economy_system`, `wildlife_system`, `combat_system`), but `main.gd` still contains large implementation blocks for rendering, UI assembly, resource indexing, day-cycle glue, and gameplay event handling.

Why previous refactor did not reduce file size:
- Logic moved into helper classes, but orchestration plus many utility and rendering details remained in `main.gd`.
- New features were still added directly to `main.gd`.
- No explicit line-budget gate existed to force extraction of new code.

## Does file size slow AI agents?
Yes, somewhat.
- Retrieval and edits are still possible, but large monolithic files increase search noise.
- Patch precision risk increases because many similarly named functions live in one file.
- Cross-cutting changes need more reads and increase chance of touching adjacent unrelated logic.

## Refactor goals
1. Reduce `scripts/main.gd` from 5779 lines to under 2200 lines.
2. Keep behavior identical during migration.
3. Enforce a rule: new feature logic must not be added to `main.gd` unless it is orchestration-only.
4. Keep frame-time stable or improved.

## Target architecture
Keep `main.gd` as a coordinator only:
- scene wiring
- per-frame scheduling
- high-level event routing
- minimal state bridging between systems

Extract implementation into domain modules:
- `scripts/systems/render_batch_system.gd`
- `scripts/systems/resource_index_system.gd`
- `scripts/systems/world_chunk_system.gd`
- `scripts/systems/day_night_system.gd`
- `scripts/systems/resource_harvest_system.gd`
- `scripts/systems/raid_system.gd`
- `scripts/ui/hud_builder.gd`
- `scripts/ui/upgrade_ui_builder.gd`
- `scripts/ui/perf_panel_ui.gd`

## Phase plan

### Phase 0 - Baseline and guardrails (no behavior change)
- Add lightweight architecture guardrail section to repo docs:
  - `main.gd` may call systems, but should not contain new domain loops.
- Add a line budget check in CI/local script:
  - warning if `main.gd` > current baseline + 50 lines.
- Capture perf baseline from in-game panel:
  - `update_settler_targets`
  - `update_settler_combat`
  - `world_chunk_streaming`
  - `draw_combined_sprite_batch`

Exit criteria:
- Baseline metrics recorded.
- Rule agreed for future PRs.

### Phase 1 - Rendering extraction (largest immediate win)
Move from `main.gd`:
- Combined sprite queue/build/flush logic
- Resource icon batched rendering helpers
- Collection particle batch setup and update

Create:
- `render_batch_system.gd` owning:
  - sprite atlas creation
  - queue APIs: settlers, indicators, particles, resource markers
  - draw flush and perf counters

Expected reduction:
- 600 to 1000 lines from `main.gd`.

Exit criteria:
- Existing visuals match.
- No increase in draw spikes.

### Phase 2 - Resource index and reload queue extraction
Move from `main.gd`:
- resource tile arrays, chunk maps, add/remove/sync helpers
- resource reload queue and processing
- nearest resource queries and patrol candidate helpers

Create:
- `resource_index_system.gd` owning all resource coordinate indexes and query APIs.

Expected reduction:
- 500 to 800 lines.

Exit criteria:
- Harvest/regrow/expire still update visuals and targeting correctly.
- Resource queue depth remains bounded.

### Phase 3 - World chunk streaming extraction
Move from `main.gd`:
- chunk rebuild queue, prune logic, rebuild function
- visible chunk computation for world draw

Create:
- `world_chunk_system.gd` with explicit API:
  - `mark_tile_dirty`
  - `process_streaming(delta)`
  - `draw_visible(camera_state)`

Expected reduction:
- 350 to 600 lines.

Exit criteria:
- Chunk streaming budget behavior unchanged or better.
- No reintroduced 30ms spikes.

### Phase 4 - UI construction extraction
Move from `main.gd`:
- `build_*_ui` and related widget wiring helpers
- resource bar, upgrades drawer, perf panel, hover panel builders

Create:
- `hud_builder.gd`, `upgrade_ui_builder.gd`, `perf_panel_ui.gd`

Expected reduction:
- 700 to 1200 lines.

Exit criteria:
- UI layout and interactions unchanged.
- No null reference regressions on resize/toggle.

### Phase 5 - Day/night and raid lifecycle extraction
Move from `main.gd`:
- dawn/dusk transitions
- overnight regrow scheduling
- raid warning/trigger orchestration
- structure raze helper chain

Create:
- `day_night_system.gd`
- `raid_system.gd`

Expected reduction:
- 350 to 650 lines.

Exit criteria:
- Raid cadence and warning behavior unchanged.
- Morning dispatch and regrow still consistent.

### Phase 6 - Combat and wildlife glue simplification
Keep heavy loops in existing systems, but remove orchestration complexity in `main.gd`:
- centralize combat/wildlife callback bridges in thin adapters
- trim state conversion in `main.gd`

Expected reduction:
- 200 to 350 lines.

Exit criteria:
- Combat and wildlife metrics stable or improved.

## New coding rules to keep `main.gd` small
1. No new domain loops in `main.gd`.
2. Any function over 40 lines in `main.gd` must be reviewed for extraction.
3. Any new dictionary schema used by multiple features must be owned by a system file.
4. If a feature touches rendering and simulation, rendering queue code belongs in render system, simulation in domain system.

## Suggested order for immediate execution
1. Phase 1 (render extraction)
2. Phase 2 (resource index extraction)
3. Phase 4 (UI extraction)
4. Phase 3 (world chunk extraction)
5. Phase 5 and 6

This order removes the most lines quickly while minimizing gameplay risk.

## Success metrics
- `scripts/main.gd` line count milestones:
  - Milestone A: < 4500
  - Milestone B: < 3200
  - Milestone C: < 2200
- Perf:
  - No regression in average frame ms.
  - Reduced max spikes in chunk, batch render, combat.
- Delivery:
  - Each phase shippable independently with no gameplay break.

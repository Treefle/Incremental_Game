# Settler Targeting Performance Optimization Plan

## Objective
Stabilize frame time by reducing `update_settler_targets` cost and eliminating stutters under high settler counts (400+), while preserving gameplay behavior.

Target:
- Keep frame budget near 16.67 ms for 60 FPS.
- Keep `update_settler_targets` under 4-6 ms average at 400 settlers.
- Keep worst-case spikes below 12 ms during day/night transitions.

## Current Situation (Observed)
From in-project profiling and code inspection:
- `update_settler_targets` is the top frame-time contributor.
- Heavy work is dominated by repeated tile scans and repeated resource queries:
  - `_nearest_resource_tile`
  - `_nearest_food_tile`
  - `_is_day_plan_valid`
  - `_resource_type_at` and `_resource_left`
- These run per-settler and often per-think cycle, multiplying costs.

## High-Level Strategy
Use a phased approach:
1. Measure and isolate exact hotspots first.
2. Remove redundant work.
3. Replace scan-based lookups with indexed data structures.
4. Spread expensive updates over time with deterministic scheduling.
5. Validate and tune with performance gates after each phase.

---

## Phase 0 - Instrumentation and Baseline (Do This First)

### 0.1 Add finer profiling counters inside targeting helpers
Track call counts and average ms for:
- `_nearest_resource_tile`
- `_nearest_food_tile`
- `_is_day_plan_valid`
- `_resource_type_at`
- `_resource_left`

Add counters for:
- Number of settlers evaluated per frame.
- Number of settlers that actually request a new target.
- Number of cache hits vs misses for plan reuse.

### 0.2 Build repeatable stress scenarios
Use fixed conditions:
- 400 settlers (current), then 800, then 1200.
- Daytime only test, then dawn test, then dusk test.
- Fixed map seed and camera placement.

### 0.3 Define pass/fail thresholds
For each scenario capture:
- Avg frame ms
- Max frame ms
- Avg and max `update_settler_targets` ms

Only move to next phase if metrics improve.

---

## Phase 1 - Fast Wins (Low Risk)

### 1.1 Early exits and skip checks
In `update_settler_targets`:
- Exit before expensive work if settler is not due for replan.
- If target still valid and far enough away, skip re-evaluation.
- For offscreen settlers, increase replan interval further.

### 1.2 Reduce duplicate computations in same frame
For each settler during one update pass:
- Compute `tile = _world_to_tile(pos)` once.
- Reuse local values for `job`, `state`, and target distance.
- Avoid re-calling `_job_for_settler` and tile conversion in same branch.

### 1.3 Minimize dictionary churn
- Avoid repeated `has/get/erase` for same keys in same branch.
- Pull dictionary values once into locals.

Expected gain: moderate reduction in CPU and temporary allocations.

---

## Phase 2 - Resource Indexing (Major Gain)

This is the key redesign and the most impactful change.

### 2.1 Build typed coordinate arrays (or packed arrays)
Maintain separate collections of active resource tiles:
- `food_tiles` (apple + berries)
- `tree_tiles`
- `stone_tiles`
- `metal_tiles`

Recommended representation:
- `PackedInt32Array` using flat tile index (`y * world_w + x`) for compactness.
- Optional companion `Dictionary<int, int>` from tile index to array position for O(1) removal by swap-pop.

### 2.2 Update indices incrementally
When resource state changes (harvested, depleted, regrown):
- Add/remove tile from corresponding index array(s).
- Do not rescan map globally.

### 2.3 Replace ring scans with indexed nearest lookup
Current methods (`_nearest_resource_tile`, `_nearest_food_tile`) do radial scan loops.
Replace with:
- Candidate iteration over relevant typed array.
- Distance comparison to find nearest valid tile.
- Optional max-distance cutoff.

Later optimization:
- Partition each typed array into spatial bins/chunks to avoid scanning all candidates.

### 2.4 Optional claim-aware view
For claimed resources:
- Keep unclaimed lists or a fast claim bitset by tile index.
- Skip claimed tiles without dictionary lookups.

Expected gain: large improvement by removing repeated ring scans.

---

## Phase 3 - Spatial Partition for Nearest Queries (Major Gain at Scale)

### 3.1 Chunked resource buckets
Store resource indices per world chunk:
- `resource_chunks[chunk_id][resource_type] -> PackedInt32Array`

### 3.2 Query nearby chunks first
Nearest search flow:
1. Start in settler chunk.
2. Expand to neighboring chunks in rings.
3. Stop when found candidate distance beats next ring lower bound.

### 3.3 Cache per-settler last successful chunk
- First query starts where settler found target previously.
- Great for temporal coherence.

Expected gain: very large for large worlds or sparse resources.

---

## Phase 4 - Scheduling and Budgeting Improvements

### 4.1 Multi-queue scheduling by urgency
Split settlers into queues:
- `urgent`: target invalid, blocked, near arrival.
- `normal`: routine refresh.
- `background`: offscreen/stable.

Process in this order within frame budget.

### 4.2 Deterministic spread across frames
- Continue using cursor-based progression.
- Add per-settler replan cooldown with jitter by queue class.

### 4.3 Transition windows
For dawn/dusk:
- Keep stricter budget (already present).
- Add temporary priority cap for non-urgent offscreen settlers.

Expected gain: fewer worst-case spikes, smoother frame pacing.

---

## Phase 5 - Wildlife and Hunter Target Query Optimizations

### 5.1 Hostile wildlife spatial cache
Currently nearest hostile checks iterate `_wildlife` frequently.
- Maintain per-frame hostile position arrays and chunk bins.
- Query nearest hostile from bins instead of full scan per hunter.

### 5.2 Shared hunter objective reuse
- Keep one shared hostile objective for hunter squads for short intervals.
- Recompute at fixed cadence (for example every 0.2-0.4 s) rather than per hunter.

Expected gain: small to moderate, helps when hunter counts increase.

---

## Phase 6 - Memory and Allocation Hygiene

### 6.1 Avoid temporary allocations in hot loops
- Prefer pre-sized packed arrays where possible.
- Reuse temporary buffers.

### 6.2 Replace string tile keys in hot path
If still using `"x:y"` keys in tight loops:
- Move to integer tile indices for hot-path structures.
- Keep string keys only where needed for existing save compatibility.

Expected gain: reduced GC pressure and stutter.

---

## Phase 7 - Rendering and Draw-Call Clarification

### Is the map using MultiMesh rendering?
Short answer: no, not for terrain tiles.

Current map path:
- Terrain is rendered as chunk textures generated in images and drawn via `draw_texture_rect`.
- Chunk rebuild is budgeted through `_process_world_chunk_streaming`.

What uses MultiMesh now:
- Settler crowd rendering in `AgentSystem` (single MultiMeshInstance2D path).
- Collection particle batch also uses a MultiMesh.

Should map switch to MultiMesh?
- Not immediately required for this bottleneck.
- Your current bottleneck is targeting/AI, not terrain draw.
- A map MultiMesh migration can help render scalability later, but should be a separate phase after AI/pathfinding wins.

---

## Suggested Implementation Order (Practical)

1. Phase 0 baseline instrumentation.
2. Phase 1 fast wins and duplicate-work removal.
3. Phase 2 typed resource index arrays with incremental maintenance.
4. Phase 4 queue/budget refinement.
5. Phase 3 spatial partition on top of typed indices.
6. Phase 5 wildlife/hunter query optimizations.
7. Optional render pipeline improvements.

---

## Verification Checklist Per Phase

For each phase:
- Record before/after:
  - Avg FPS
  - Avg frame ms
  - Max frame ms
  - Avg/max `update_settler_targets` ms
- Confirm gameplay correctness:
  - Settlers still replan and recover from blocked paths.
  - Day/night transitions remain correct.
  - Resource claims and depletion logic remain consistent.
- Keep a rollback commit point after each phase.

---

## Concrete Data-Structure Proposal for Resource Coordinates

### Core arrays
- `food_tile_indices: PackedInt32Array`
- `tree_tile_indices: PackedInt32Array`
- `stone_tile_indices: PackedInt32Array`
- `metal_tile_indices: PackedInt32Array`

### Fast removal support
- `tile_index_to_pos_food: Dictionary<int, int>`
- (same for other arrays)

Removal algorithm:
1. Lookup position in dictionary.
2. Swap with last element in packed array.
3. Update swapped element position in dictionary.
4. Pop last and erase removed key.

This keeps insert/remove near O(1) and avoids map scans.

---

## Risks and Mitigations

Risk:
- Index arrays drift out of sync with actual resource state.

Mitigation:
- Centralize all resource mutations through one API (`_set_resource_left` and regrow hooks).
- Add debug assertions in development builds (sample-check random tiles).

Risk:
- Behavior regressions from aggressive budgeting.

Mitigation:
- Keep urgency queue for blocked/near-arrival settlers to preserve responsiveness.

---

## Bottom Line
The stutter is primarily an AI query architecture issue, not a draw-call issue.
The biggest practical win is to move from repeated radial scanning to indexed resource coordinate arrays (and then chunked spatial lookup), while keeping budgeted scheduling for transitions.

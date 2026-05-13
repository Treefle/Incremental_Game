# Performance Optimization Plan - Toward 1000 Concurrent Settlers

## Objective
- Primary goal: support 1000 concurrent settlers with stable frame pacing.
- Suggested target: 55-60 FPS on a typical mid-range desktop, or at least 45 FPS with heavy combat/events.
- Secondary goal: maintain clear player feedback (task state and decision/thinking status) while reducing CPU cost.

## Baseline Signals (From Current Perf Panel Screenshot)
- Settlers: 400
- FPS: 17
- Frame time: ~45.75 ms average, ~139.76 ms max spike
- Most expensive tasks observed:
  - update_settler_targets (avg ~10.37 ms)
  - draw_world_tiles (avg ~9.62 ms)
  - update_fog_reveal (avg ~9.35 ms)
  - update_minimap_tick (avg ~6.75 ms)
  - draw_collection_particles (avg ~2.24 ms)

Interpretation:
- AI targeting + map drawing + fog/minimap refresh are dominating frame cost.
- Hitting 1000 settlers requires reducing per-frame whole-population work and reducing frequent full-map redraw work.

## High-Impact Changes (Priority Order)

### 1) Reduce fog/minimap update cadence to once per second
- Change minimap update interval from 0.08s to 1.0s.
- Change fog reveal update interval from 0.1s to 1.0s.
- Optional quality mode:
  - High: 0.25s
  - Balanced: 0.5s
  - Performance: 1.0s

Expected impact:
- Large reduction in map/fog CPU usage, especially with many settlers.

Risk:
- Slightly delayed visual feedback on explored area/minimap.
- Usually acceptable for strategy simulation pacing.

### 2) Stagger settler decision making (not all settlers every AI tick)
- Current pattern re-evaluates targets in broad batches.
- Move to a scheduler where each settler has next_think_time.
- Settlers can wait up to 1-3 seconds before selecting a new task target, unless an interrupt condition occurs.
- Add random jitter per settler (example: 0.15-0.35s offset) to avoid decision spikes.

Proposed think cadence:
- Idle/unassigned: every 0.5-1.0s
- Moving/working normally: every 1.5-3.0s
- High-priority events (threat, task invalid): immediate interrupt think

Expected impact:
- Very large reduction in update_settler_targets spikes.
- Better frame stability by distributing work over time.

### 3) Add thinking indicator for delayed decisions
- Requirement: if a settler is waiting for next think, show indicator.
- Keep indicator lightweight:
  - Option A: tiny icon above settler from a shared atlas/glyph
  - Option B: single pulsing dot with color state
- Update indicator state only when logic state changes, not every frame.

State model example:
- Thinking: waiting for next decision tick
- Executing: has active task and valid target
- Blocked: target invalid/unreachable; waiting retry

Expected impact:
- Preserves user clarity while enabling slower AI reevaluation.

## Additional Optimization Ideas

### 4) Incremental target updates instead of full pass
- Update only a fixed budget of settlers each frame (for example 100-250 settlers/frame), rolling index.
- Full population gets updated across multiple frames.
- Emergency events can queue immediate updates for affected settlers.

### 5) Cache and invalidate nearest resource queries
- Nearest tile searches are expensive when repeated.
- Keep cached targets per settler and only recompute on invalidate conditions:
  - resource depleted
  - target reached
  - path blocked/unreachable
  - job changed
- Build optional per-resource spatial buckets to accelerate nearest lookup.

### 6) Decimate expensive draw layers
- draw_world_tiles appears expensive; avoid redrawing unchanged regions where possible.
- Consider chunked tile rendering cache (dirty-chunk redraw) rather than full visible tile repaint every frame.
- Throttle decorative particle rendering and cap max live particles based on FPS budget.

### 7) Dynamic quality scaling based on frame budget
- Deferred: do not implement this in the current optimization pass.
- Reason: adds system complexity and can hide root-cause bottlenecks while we still have clear fixed wins available.
- Revisit only after core AI scheduling, rendering, and logging costs are reduced.

### 8) Logging overhead controls
- Global settler logging can become expensive under heavy load.
- Throttle logging aggressively in performance runs:
  - Snapshot interval: 2.0-5.0s (not sub-second).
  - Event sampling: only log state changes and significant transitions.
  - Optional per-settler sampling rate (for example 1 in N settlers during stress).
- Keep snapshots sparse and disable detailed logs in performance mode.
- Ensure buffered write limits and drop policies are explicit.
- Add counters in perf panel: log lines/sec, dropped lines, flush duration ms.

## Suggested Implementation Phases

### Phase A - Immediate (1-2 sessions)
- [ ] Set fog/minimap interval to 1.0s
- [ ] Implement think scheduler with 1-3s cadence + jitter
- [ ] Add thinking indicator state above settlers
- [ ] Add perf metrics for decision queue depth and per-frame settlers processed

### Phase B - Core Throughput (2-4 sessions)
- [ ] Incremental/budgeted target updates
- [ ] Resource lookup cache + invalidation rules
- [ ] Throttle global logging (intervals, sampling, drop policy visibility)

### Phase C - Rendering and Long-Tail (3-6 sessions)
- [ ] Chunked world draw cache / dirty region redraw
- [ ] Particle cap and draw-effect throttling
- [ ] Draw call simplification for overlays/markers where possible
- [ ] Keep dynamic quality scaling deferred (do not implement #7)
- [ ] Final tuning for 1000 settlers stress scenarios

## Ordered Execution Checklist (Work Through In Order)
1. Apply fixed update cadence reductions:
  - minimap interval = 1.0s
  - fog reveal interval = 1.0s
2. Implement settler think scheduling (1-3s cadence + jitter).
3. Add thinking indicator states (Thinking, Executing, Blocked).
4. Introduce budgeted target updates per frame (rolling index).
5. Add resource target cache invalidation rules in this order:
  - resource depleted
  - target reached
  - path blocked/unreachable
  - job changed
6. Throttle logging for stress runs:
  - increase snapshot interval
  - reduce event granularity to state changes
  - add sampling and dropped-line reporting
7. Implement rendering optimizations:
  - chunk/dirty redraw for world tiles
  - particle cap and effect throttling
  - simplify expensive overlay draws
8. Run 1000-settler validation pass and tune thresholds.

## Proposed Metrics to Track
- FPS (avg, p1 low)
- Frame time (avg, p95, p99)
- update_settler_targets avg/max ms
- draw_world_tiles avg/max ms
- fog/minimap update avg/max ms
- settlers updated per frame (decision budget)
- percent of settlers in Thinking vs Executing vs Blocked

## Acceptance Criteria for 1000 Settlers
- 1000 settlers running for 10 minutes without hard stutter spirals.
- Frame time p95 within target band (for example <= 22 ms for ~45 FPS minimum).
- update_settler_targets no longer the dominant spike source most frames.
- Fog/minimap updates no longer produce major frame spikes.
- Thinking indicator correctly communicates delayed decision behavior.

## Concrete Default Settings Proposal
- minimap interval: 1.0s
- fog reveal interval: 1.0s
- settler normal think interval: 2.0s
- settler idle think interval: 0.75s
- settler think jitter: +/- 0.2s
- emergency interrupt think: immediate

## Notes
- 1000 settlers is achievable if we stop doing whole-population expensive logic every short tick.
- The biggest wins should come from scheduling, cadence control, and avoiding full-world redraw-style work every frame.

# AI Settlers Job Processing Bug Tracker

## Overview
- Bug title: AI settlers job processing
- Owner:
- Priority: High
- Status: Open
- Created: 2026-05-12
- Last updated: 2026-05-12

## Current Summary
When many settlers are active at once, some settlers fail to maintain a stable job assignment and appear to drop, switch, or stall tasks before completion. Initial suspicion is that job state is being disrupted by the move-to-target-position logic during high-concurrency updates. The system should support player-selected priority boosts for locations/tasks while still allowing the behavior tree to gate final execution timing.

## Reproduction
1. Start a scenario with high settler count and enough available jobs to keep all settlers active.
2. Let settlers concurrently path and process tasks for several in-game cycles.
3. Observe job persistence and task completion behavior as multiple settlers re-evaluate targets.
4. (Optional) Select a location/task to raise priority and observe whether assignments remain coherent.

### Expected Result
- Settlers retain assigned jobs until completion or a valid behavior-tree transition occurs.
- Move-to-target updates should not unintentionally clear or replace active job state.
- Selecting a location/task raises its priority in assignment decisions.
- Behavior tree remains the final authority on whether/when a task is executed.
- Each settler displays current task text and associated job icon above the character.

### Actual Result
- Under high simultaneous activity, some settlers appear to lose or churn job assignments.
- Symptom appears correlated with movement/targeting updates.
- No reliable, at-a-glance task + icon display above settlers for debugging/gameplay feedback.

## Scope and Impact
- Affected systems: job assignment lifecycle, movement-to-target mechanic, behavior tree task gating, settler UI feedback
- Affected scenes/scripts: scenes/main.tscn, scripts/agent_system.gd, scripts/flow_field.gd, scripts/main.gd
- Player-facing impact: settlers look unreliable; high-unit gameplay becomes hard to control and debug
- Frequency: high when many settlers operate simultaneously

## Investigation Log
| Date | Author | Findings | Evidence (logs/screenshot/file) | Next Step |
|------|--------|----------|----------------------------------|-----------|
| 2026-05-12 |  | Tracker created |  | Add first repro details |
| 2026-05-12 | User report | Job persistence fails under load; likely linked to move-to-target logic; priority boost + overhead task/icon UI required | User description; pending logs/video capture | Reproduce with instrumentation around assignment and movement state transitions |

## Hypotheses
- [ ] Movement state updates overwrite active job state when path target changes.
- [ ] Task selection lacks assignment stickiness/locking under concurrent agent updates.
- [ ] Priority changes are not represented in the scheduler as weighted hints.
- [ ] Behavior tree transitions can preempt jobs without preserving completion intent.

## Fix Plan
- [ ] Add instrumentation logs for: job assigned, job changed, move target changed, task completed, task aborted
- [ ] Reproduce with controlled load (small, medium, large settler counts)
- [ ] Implement assignment stickiness (do not drop job during movement unless explicit interrupt condition)
- [ ] Implement priority boost channel for selected locations/tasks as weighted preference
- [ ] Ensure behavior tree consumes priority as a hint but still controls final execution timing
- [ ] Add settler overhead UI: current task label + job icon
- [ ] Add/adjust tests (if available) for persistence, priority influence, and UI state sync
- [ ] Validate in-game behavior under stress and run regression checks

## Validation Checklist
- [ ] Repro no longer occurs with original steps
- [ ] No errors/warnings introduced in output logs
- [ ] Settlers complete assigned jobs correctly
- [ ] Job queue state remains consistent over time
- [ ] Priority-selected locations/tasks are chosen more often when valid
- [ ] Behavior tree can still defer/deny execution appropriately
- [ ] Overhead task text matches internal active task state
- [ ] Overhead job icon matches task type and updates on task transitions
- [ ] Performance remains acceptable with many simultaneous settlers

## Risks and Notes
- Risk: Overly strong priority boosts may starve non-selected essential jobs.
- Risk: Assignment stickiness may reduce responsiveness if interrupt rules are too strict.
- Note: Define explicit interrupt conditions (threat, unreachable target, higher-priority emergency, task invalidation).

## Resolution
- Resolved date:
- Commit/changes:
- Final root cause:
- Final fix summary:

## Acceptance Criteria
- Under high settler counts, active jobs remain stable unless interrupt conditions are met.
- Selecting a location/task measurably increases its assignment priority without bypassing behavior-tree authority.
- Settlers always show current task + matching job icon overhead while a task is active.

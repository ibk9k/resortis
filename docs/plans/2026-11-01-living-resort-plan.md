# Living resort implementation plan

Date: 2026-11-01, Asia/Karachi. Status: **implemented and verified**. Approval: "Alright go ahead" after the six-worker proposal. Final results, independent acceptance and shared interfaces are recorded in `living-resort-progress.md`, `living-resort-qa.md` and `living-resort-contract.md` beside this file.

## Outcome and team

Build a small, working management loop: several guests arrive, reserve different cabins, choose activities from their needs, compete fairly for usable furniture, react to dirt and receive help from a hired janitor. The player can inspect people, facilities, cleanliness and operating results.

Use **six separate worker chats: five implementation workers and one independent QA/review worker**, with this chat as coordinator. Maximum three workers actively executing at once. These are six workers total, not six workers plus additional hidden subagents. Start them only after approval. Each chat receives AGENT.md, the approved scope, its file ownership, dependencies and acceptance criteria. The coordinator remains accountable for the finished game.

## Approved scope requested

| No. | Change | Owner | Acceptance |
| --- | --- | --- | --- |
| 1 | Multiple active bookings and replenishing arrivals, targeting 8–12 simulated people where available cabins allow. Replace the decorative crowd with real customers as the population system takes over. | Worker 1 | No duplicate room reservations or overlap between active bookings. Full/blocked resorts produce an explained wait or departure. Population respects accommodation and a documented small proof cap. |
| 2 | Needs-driven activity choices using hunger, rest and enjoyment. Guests choose meals, rest, strolling, sunbathing or an available volleyball partner. | Worker 2 | Different needs cause different choices. Unavailable or unaffordable activities have sensible alternatives. Guests do not switch tasks every update or get stuck repeating an impossible action. |
| 3 | Guest variety: solo/couple arrivals, 1–3-night stays, different budgets and 2–3 interests. | Workers 1 and 2 | Stable generated profiles survive save/load. Ordinary guests preserve unpaid room money; nightly and facility charges occur exactly once. Repeated arrivals vary without requiring new guest models. |
| 4 | Shared facility capacities, separate physical seats/loungers, bounded visible queues and waiting points. Pair volleyball participants on opposite sides of the net. | Worker 3 | No double-booked seat or lounger, overlapping waiting positions, queue jumping or activity payment before admission. Timeouts and cancellation release reservations. Queues preserve paths and entrances. |
| 5 | Couple coordination: shared lodging, optional shared leisure, occasional separate activities based on individual needs, and reunion before overnight rest or departure. | Worker 3, with Worker 2's decisions | Partners have independent movement/needs, cannot hold each other in an endless wait and cannot orphan bookings or furniture when separating/rejoining. Both identities remain inspectable. |
| 6 | Event-driven litter/spills around used facilities; local cleanliness affects guest mood. Explain complaints and show a warning/grace period before an early checkout for sustained severe dissatisfaction. | Worker 4 for dirt; Worker 2 for reactions | Dirt is bounded, appears in valid reachable locations and is not generated once per rendered frame. Guests react locally; cleaning permits recovery and cancels a recovered guest's departure warning. |
| 7 | Hire/dismiss janitors through a simple staff panel. Janitors find reachable mess, walk there, visibly clean it and continue working. Matching illustrated staff appearance and cleaning action. | Worker 4 | One cleaner claims each job. No cleaning from a distance or through obstacles. Path edits, dismissal, completed jobs and save/load release or restore claims safely. New staff art passes motion, scale and clipping review. |
| 8 | Management information: guest list/profiles, facility occupancy/queue information, cleanliness/staff status and a daily operating summary of room/activity income and janitor wages. | Worker 5 | Displayed figures reconcile with simulation events. Guest selection/follow works for every customer. Hiring controls affect the same simulation that the UI reports. The existing scene speeds/pause remain usable. |
| 9 | Versioned saves for all guests, bookings, individual needs, queues, staff/jobs, mess, operating totals and random-generation state. Preserve legacy layout/solo/couple saves and existing edit protections. | Coordinator; Worker 6 verifies independently | Save/resume mid-queue, meal, split couple, cleaning job and checkout matches uninterrupted play. Invalid files do not replace the open resort. No duplicate payments, wages, bookings or job claims. |

This is an ordered implementation schedule, not a calendar automation or a claim about completion dates.

## Worker assignments and boundaries

1. **Population and bookings:** owns the new resort simulation/population controller, arrival scheduling and room-reservation registry. Implements item 1 and the arrival side of item 3. Provides shared reservation/time/event contracts before dependent integration.
2. **Guest decisions and profiles:** owns the stay/decision rules, profile generation, individual needs, interests and dissatisfaction warnings. Implements items 2/3 and the guest-reaction side of item 6. Keeps existing supported solo/couple behavior working while extending it.
3. **Facilities and couples:** owns facility sessions, capacities, waiting positions/queues, volleyball pairing and party coordination. Implements items 4/5 against the booking/decision contracts. Reuses the accepted guest poses and measured furniture fixtures.
4. **Cleanliness and janitors:** owns mess/job state, janitor routing/cleanup, staff data and new staff-only assets. Implements items 6/7 and emits wage/hiring events for the operating summary. Does not alter the approved guest masters or walking frames.
5. **Management panels and operating summary:** owns new guest/staff/facility/operations UI components and the income/wage ledger. Implements item 8 and exposes controls for items 6/7. Reads simulation state; does not own duplicate gameplay state in the UI.
6. **Independent QA and review:** writes acceptance scenarios from this approved plan, tests workers' outputs, reviews the integrated code and reports defects with reproductions. Tests legacy-save migration, money/reservations, queue/job ownership, blocked paths, couples, speeds, visual regressions and the small-population performance sample. Does not self-approve a feature based on the producing worker's report.

The coordinator owns shared scene/HUD integration points, top-level save migration, shared-file edits, source snapshots, art baking/imports, project documentation and final acceptance. Workers use separate owned modules; changes to another owner's files are requested through the coordinator. The project has no Git repository, so there will be no invented branches, commits or worktrees. Only the coordinator updates shared derived scenes and reviewed-source approval.

## Execution schedule

**Preparation — coordinator:** preserve a recoverable source baseline and the player's saves/backups; run the existing checks; define the shared clock, identity, reservation, activity, job, event and snapshot contracts; write the task briefs and file ownership. This work begins after approval.

**Wave 1 — Workers 1, 2 and 6:** build population/bookings and needs/profile rules in parallel while QA prepares independent scenarios. Coordinator integrates a playable multi-booking checkpoint and verifies legacy solo/couple behavior before the next wave.

**Wave 2 — Workers 3, 4 and 5:** build facilities/couples, dirt/janitors and management panels against the accepted interfaces. Coordinator integrates each result, resolves shared-file changes and reviews new staff/dirt art. QA waits or is resumed when a worker slot becomes available.

**Wave 3 — Worker 6 plus targeted fixes:** independently exercise the combined resort. Producing workers fix their assigned defects; coordinator checks fixes, runs the full regression suite, reviews actual game renders/motion and publishes the final change summary. A worker's completion message is a handoff, not acceptance.

## Working tuning and limits

- Start with a measured 8–12-person proof where rooms permit; do not promise the later 100–200-guest target. Do not spawn extra real guests on top of fourteen decorative walkers and call that the new population system.
- Keep the current room/facility fee defaults initially: $60 per cabin-night; café $12, loungers $8 and volleyball $10 per person per use. The cabin price is shared by a couple. Define stay-length/budget generation so room reserves remain coherent.
- Use the existing 180-simulation-second day as the initial tuning reference. One shared clock drives arrivals, wages and needs, with a documented rule for preserving legacy night deadlines.
- Janitor wage, hiring cost if any, dirt rate, cleaning duration, dissatisfaction thresholds and queue limits will be documented tuning values; choose reversible defaults during implementation and report them with the finished changes. No paid tools or assets are proposed.
- The finance scope is an operating income/expense summary. Construction charging, loans and a full financial-recovery system are later work; the current building/editing workflow is not silently converted to a new economy.
- The janitor type must match the accepted illustrated art direction. Current male/female guest appearance and walking assets stay protected. Any new poses must be complete coherent drawings, visually reviewed in motion; no rejected walking deformation or rotating limb cutouts.
- No maintenance worker/wear system, fishing gameplay, new building catalogue, progression/missions, full Creative controls, autosave/manual-slot UI, thirst/hygiene/bathroom simulation or further guest redesign is included in this batch.

## Coordinator's final acceptance

1. Independently read each worker's changes and reproduce its claimed behavior. Return defects to the responsible worker instead of accepting a status message.
2. Demonstrate concurrent different-cabin bookings; a full café/sunbed queue; opposite-side volleyball; split/rejoined couples; a dirty area, a complaint and a janitor's actual cleanup; and completed 1–3-night stays with reconciled income/wages.
3. Verify pauses, 1×/2×/4× and equivalent elapsed-time runs. Check FPS-independent walking and that the new simulation does not reset its pose clock.
4. Test mid-action save/resume, legacy migration, malformed saves, payment/job idempotency and occupied-object/path editing. All tests bind isolated saves before startup; they never write the player's `coastal-layout.json` or `.bak`.
5. Run existing and new regressions. Inspect both cabin facings, furniture occlusion, all guest walking directions and new janitor motion at normal and enlarged sizes in actual Godot renders. Passing numerical tests is not visual approval.
6. Profile the representative small crowd and document measured results/remaining limits. Rebuild affected asset outputs, review them, then update source approval and confirm its checks pass.
7. Deliver the working integrated build, concise feature/test results, known limits and updated canonical project documentation. Keep this chat as the single progress/decision point while workers report here.

## Approval record

The user approved the nine changes, six-worker team and three-wave execution with “Alright go ahead” on 2026-11-01. All six chats were created under that authorization. Current status/results are recorded in `living-resort-progress.md` and `living-resort-qa.md`.

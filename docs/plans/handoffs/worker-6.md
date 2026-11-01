# Worker 6 — independent QA handoff

## Final independent world/UI/render review — 2026-11-01

**Final independent status: ACCEPTED for the approved living-resort slice. World/save/UI/edit/clock/crowd/render checks pass, and the final combined dirt-warning → actual janitor cleanup → same-position recovery case is now independently closed. No unresolved W6 production finding or pending approved acceptance requirement remains.** The earlier three wrapper defects are fixed and independently closed. This is acceptance of the documented small proof, not a claim that later roadmap features or 100–200-guest performance are complete.

All older wave sections below are historical. Their “pending”, parse blockers and open wrapper findings are superseded by this final section. The rejected queue experiment is retained honestly and is not counted as a pass. No production files, another worker's tests, player saves, imports/bakes or source-approval files were modified by W6.

### Final combined mood case: independently accepted

W6 read the complete `tests/living_mood_checks.gd`, reviewed the real brain's rates/thresholds/recovery code, and ran **only that focused test** as requested. Project-local Godot exited **0** and `passed:true`. Evidence: `artifacts/worker-6-final-mood.log`, `artifacts/living-mood-checks.json`, and `artifacts/worker-6-mood-independent-review.json`. All **11 independent result/safety checks** in the review artifact are true.

This is an **explicit controlled behavioral fixture**, not a naturally observed severe-dirt incident or a GPU demonstration. It first reaches genuinely checked-in, strolling Leo in the authored map. The saved fixture then places him at verified open/reachable beach **(35,23)** with a 60-second route wait and healthy initial needs, plus eight spaced pre-existing reachable spill marks. The **complete JSON envelope must restore successfully before the run**. Bookings, receipts, IDs and services remain intact. No production tuning or method is changed, and no staff position, claim, transaction, mood, warning or recovery is fabricated during advancement. The earlier proposed (39,25) point was blocked and correctly rejected; it is not the final fixture.

Actual shared-clock result:

- **37.0s:** fixture starts. Local cleanliness score 0; eight spills; no cleaners.
- **55.0s:** real dirty-area complaint and grace warning; mood **24.908**, hunger **86.04**, rest **87.12**, enjoyment **100**. The reason explicitly names the mess. The runtime hires three real janitors successfully.
- **72.9s:** the cleaners have physically routed, claimed and removed **six spills**. Score at the unchanged guest root rises to **64.8758**, mood to **64.4997**, warning to **0**, and `want_leave:false`. History records both considering early checkout and cancelling its warning. The guest is still at **(35,23)**, **17.9 seconds** after the warning, inside the 30-second grace.

The 60-second movement wait has not elapsed at recovery. No food or sleep occurs, hunger/rest decline, and enjoyment was already clamped at 100 when the warning began, so it cannot explain the later mood increase. The same-position recovery is attributable to the improved actual cleanliness score. W6 separately checks all three hires, actual cleanup count, healthy warning needs, score increase, within-grace timing, cancelled warning and unchanged protected save hashes. Thus the final case closes the earlier experimental proof gap without weakening its assertions.

The natural no-staff run remains archived as `artifacts/living-mood-natural-probe.json`: it reached 16 mess records but did not trigger a severe warning in that sample. Do not describe the controlled fixture result as natural warning incidence. Natural incidence/balance tuning is not established by this proof; the required combined warning/recovery behavior is established.

### Final direct executions

- **Actual default world: 186 assertions, zero failed cases, zero pending, exit 0.** `artifacts/worker-6-final-world.log` and `living-resort-checks-world.json`.
- **Latest actual file/save/legacy suite: 73 assertions, zero failures, exit 0**, independently rerun after root's last schema-3 staging fix. `artifacts/worker-6-final-layout-save.log`. Read the new file test and loader branch: complete `LivingResortRuntime.import_legacy` validation now precedes map commitment, including fractional old `route_index` rejection. Six real schema-3 phase files, malformed collections/IDs/facings/coordinates, atomic-write preservation and historical payments are tested.
- **Exact three cross-service reproducers: 21 assertions, zero failures/pending, exit 0.** `artifacts/worker-6-final-reject.log`; missing live tickets and forged guest/staff journal ownership now reject transactionally. Reviewed root's bidirectional ownership and canonical receipt/category/history validation.
- **Final brain dirt/warning/recovery: 11 assertions, zero failures/pending, exit 0.** `artifacts/worker-6-final-brain.log`. The added observation fields are evidence, not weaker assertions: with needs held at 90, score 0 gives mood **24.95825**, first warning at **18.25s**, then warning elapsed **30s** and early-departure intent. The score-100 control remains mood **89.95825**. Switching the same warned brain fixture to score 100 during grace restores mood **89.95825**, warning **0**, and `want_leave:false`. This proves the real brain interface; it does not by itself prove actual janitor-driven combined recovery.
- Root reports its complete old/new gate passed, including W6 combined **2,867** assertions at that gate revision, zero failed/pending, native clipping zero hidden pixels, catalogue/frames, staff baked checks and source review. W6 did **not** duplicate the full gate; its later focused world run includes additional active-dismissal, move-commit and live-wage assertions and independently passes 186.

### What the actual default-world run exercised

- Living mode remains the default; ambient walkers absent; population presentation attached. Actual pause and 1x/2x/4x calls operate on the complete shared envelope.
- Every live identity present during the UI check had its actual guest-row button, Follow button, camera target and opaque actor picking exercised. Actual Hire/Dismiss buttons change the same service/UI rows. A separately restarted **real active-cleaning save** verifies dismissing the cleaner releases its genuine mess claim.
- All four actual management panels fit between HUD/build tray at 1440×900 and 960×600. Actual Results income matches the live journal; a later real day boundary shows signed, nonzero janitor wages. The panel's responsive layout and preserved scrolling were also independently inspected in rendered images (sample compact image is labeled as a sample, not gameplay).
- Five real Save → new-default-scene startup → complete-envelope comparisons → **ten more seconds of uninterrupted-original versus restarted-scene** comparisons passed: queue **135.6s**, split **80.8s**, cleaning **105.2s**, meal **131.7s**, checkout **385.7s**. The queue is captured in a fresh default scene because the initial speed/resume scenario had already advanced past that short queue; no ticket was fabricated or assertion removed.
- Actual malformed paid-meal file with all tickets removed rejects without replacing open objects/live state. Fractional envelope/person and missing service files also reject.
- Booked cabins and protected facilities reject Move/Rotate/Remove; a previously opened move cannot bypass the commit guard. Blocked undo/redo preserve history. The actual edit/restore seam rejects removing routes and leaves the layout unchanged.
- **Nine complete-world clock comparisons pass:** 30/60/120 FPS × 1x/2x/4x, with equal elapsed simulation time through a global day/payroll boundary. Full services agree, and rendered actors preserve each person's actual walked distance/phase.

### Genuine rendered crowd measurements

Actual Windows Compatibility renderer / OpenGL, **AMD Radeon RX 9060 XT**. Each run samples **600 actual rendered frames**, has **10 customers with reserved cabins throughout, at least five concurrent bookings, one hired janitor and zero ambient walkers**. These are actual W1 customers with profile/needs/routes/bookings, not decorative duplicates. The six-cabin map is validated, written only to an isolated artifact save, and loaded by the ordinary default scene. “Accommodated” here means a live party owns a cabin; it includes customers still walking to their reserved cabin.

| Speed / live panel | Wall frame p50 / p95 ms | World CPU p50 / p95 ms | Static memory | Last-frame draw calls |
| --- | --- | --- | --- | --- |
| 1x / Guests | 5.624 / 17.014 | 0.283 / 0.937 | 59,265,808 bytes | 178 |
| 2x / Facilities | 5.497 / 6.248 | 0.248 / 0.736 | 58,761,910 bytes | 155 |
| 4x / Results | 5.483 / 6.565 | 0.560 / 0.938 | 58,920,512 bytes | 146 |

Logs: `artifacts/worker-6-crowd-{1x,2x,4x}.log`. Reports/PNGs: `artifacts/living-resort-worker6-crowd-{1x,2x,4x}.json`, matching `-overview.png` / `-closeup.png`. No simultaneous GPU profiling; root held its activity/gate renders for these measurements. Wall pacing includes OS/vsync and is not a GPU execution timer. The varying panels are disclosed; this is a small proof sample, **not** a controlled speed-scaling benchmark, a 60-FPS guarantee, or evidence for 100–200 guests. Restricted shader-cache creation warnings were nonfatal; rendering and each capture returned exit 0.

### Actual visual inspection, not PNG-existence approval

Using the project's product/visual context and Impeccable product guidance, W6 opened and inspected:

- Real Guests, Facilities, Staff and Results panels over the game. Clear gold active tab, cream/sage hierarchy, readable reasons/prices/roles, consistent green surfaces, separate scrolling and intact top/bottom controls. Actual occupancy distinguishes Maya using a lounger from Lina approaching a held place; Results correctly shows $180 room + $8 sunbeds = $188 at the captured instant. Staff shows claim, wage, work state and changing progress.
- Native meal, queue, sleep, split and cleaning images supplied by root, both cabin facings in the resort, correctly supported café/lounger/bed poses, and far-player/net ordering. No newly observed guest/furniture alignment defect.
- **16 actual default-world staff walking frames** (`living-resort-worker6-staff-motion-motion-00`…`15.png`) and **16 actual cleaning frames** (`living-resort-worker6-cleaning-motion-motion-00`…`15.png`), including first/middle/last views. Walking roots follow paths, the figure passes behind vegetation/lamps at appropriate depth, shoe registration is stable, and complete sweeping poses keep planted feet while the broom/progress moves. Also inspected `staff-grounding-review.png` and all-eight-facing source-render sheets at frame 00/06/10 at normal/enlarged scales. The sheets supplement, not replace, real-world frames.
- **40 actual mixed female/male volleyball frames** (`living-resort-worker6-volley-motion-motion-00`…`39.png`) covering a full ~4-second rally cycle. Viewed 00, 09, 19, 29 and 39: the ball is visible away from first contact, passes above the net at mid-flight, reaches the nearer female forearm/hand and returns to the far male. Participants face inward on opposing measured sides. This isolated court-pair fixture changes only needs/interests and available facilities before ordinary controller choices; it never injects a ticket, route, fee or renderer pose. Normal default male/male rally capture was also inspected.

Capture helper additions are owned QA only: `--fixture=six-cabins|court-pair`, `--output-tag=...`, `--section=...`, `--speed=...`, `--seek-people=...`, `--hire-cleaner`, `--sequence-frames=...`, and `staff-walking` condition. Per-tag reports prevent overwriting root's captures. Automatic `captured_review_pending` means a helper cannot self-approve art; this written review is the independent adjudication.

### Historical rejected queue experiment: do not count as a pass

The probe was already in flight when root asked to avoid a duplicate and took over the natural scenario. It ran once; no repeat was started. `--only=dirty-world`, `artifacts/worker-6-dirty-world.log`, `living-resort-checks-dirty-world.json`: **10 checks, one failing case (two failed assertions)**. It starts from an actual default-world queued save, generates dirt through the real service, concentrates it on validated nearby reachable cells, and holds existing occupied activity timers at 50 seconds. The full wrapper validates the controlled state. No guest root/queue/fee/render pose is forged.

Actual results: person 5 at sunbeds, needs held at 60, initial local score **0**, genuine warning/panel notice at **153.6s** (start 135.6s), mood **24.0769**. Actual UI hires three cleaners; **five real jobs finish**, warning clears, `want_leave:false`, mood reaches **43.0400** at **187.3s**. However, the target has moved **2.3221 tiles** and local score at the old queue point remains **38.4156**. Existing ticket/queue timeouts/promotion allow it to move despite the longer activity timers. Therefore the fixture does **not** isolate cleaning-only recovery; the within-grace and same-position assertions correctly remain failed. This is an unfulfilled proof assumption, not a demonstrated production defect and not grounds to weaken those assertions.

The coordinator's separate validated stationary-route fixture at **(35,23)** subsequently passed and was independently reviewed/rerun by W6 as documented above. It closes the acceptance gap; this queue experiment's two failed assumptions remain historical and are not relabeled as passes. No natural warning incidence is claimed.

Performance capture detail: overview/closeup images are taken at the 1x scenario seek before profiling; the helper then explicitly selects the reported 1x/2x/4x speed for the 600-frame measurement. Thus a gold 1x button in a pre-sample overview is not a screenshot of the later speed-selection step. Actual speed behavior is separately verified by the nine whole-state FPS/speed comparisons.

### Save protection and scope

Every report preserves the four save existence/hash records: workspace `coastal-layout.json`/`.bak` remain absent; direct-play save remains SHA-256 `54bf10e9ad69ce6c36b36c581310c41d71cc6732543053ca3df11004dbab5d0a`, backup `2331b64c922beee1277ea7508ee42ece78f06b0cc95d0a5c307e8096383981a0`. The final independent mood run separately verified the same four records unchanged. No user save or accepted guest art was edited. Root owns final gate, documentation, source approval and launching the game. All approved W6 acceptance cases are now closed; no unresolved W6 finding remains.

## Latest: wave-2 backend integration review

Date: 2026-11-01, Asia/Karachi. **Backend review complete for this resumed turn; three reproducible cross-service snapshot defects remain. Default-world/UI/GPU acceptance is held pending coordinator clearance.** No production source, another worker's tests, imports/bakes or player saves were changed. Finish this turn so the coordinator can allocate the slot; resume explicitly for full-world audit.

### Actual focused results

Every command used the project-local Godot console, `--headless`, an absolute artifact log, and `tests/living_resort_checks.gd -- --only=SECTION`. Sections have separate JSON reports under `artifacts/living-resort-checks-SECTION.json`. All reported assertions include save safety; no subset is global acceptance.

| Section | Actual result | Absolute-log filename under `artifacts/` |
| --- | --- | --- |
| profiles | 1,755 checks, 0 failed/pending, exit 0 | `worker-6-backend-profiles.log` |
| brain | 11 checks, 0 failed/pending, exit 0 | `worker-6-backend-brain.log` |
| population (W1 component, separate from real services) | 46 checks, 0 failed/pending, exit 0 | `worker-6-backend-population.log` |
| facilities | 103 checks, 0 failed/pending, exit 0 | `worker-6-backend-facilities.log` |
| cleanliness | 662 checks, 0 failed/pending, exit 0 | `worker-6-backend-cleanliness.log` |
| ledger | 25 checks, 0 failed/pending, exit 0; now asserts exact lifetime and per-day display totals | `worker-6-backend-ledger.log` |
| legacy (direct W1 import) | 22 checks, 0 failed/pending, exit 0 | `worker-6-backend-legacy.log` |
| **backend** (real `LivingResortRuntime`, all attached services) | **49 checks, 1 failed case, 0 pending, exit 1**. Normal operation and all five resume probes pass; the corruption case has 6 failed assertions from 3 accepted invalid snapshots and changed open state. | `worker-6-backend-integration.log` |
| backend-court | 16 checks, 0 failed/pending, exit 0; actual autonomous cross-party rally | `worker-6-backend-court.log` |
| backend-reject | 21 checks, 1 failed case, exit 1; fast replay independently confirms the same three invalid accepts | `worker-6-backend-reject.log` |

The previous wave-1 parse blockers no longer reproduce. Profiles, needs/mood, reservation/capacity, FIFO, physical queues, payroll and ledger were read independently as well as tested. Current ledger inspection keys are `income_total`, `wages_total`, `net_total`, `today_income/today_wages/today_net`, `day`, `days`; its displayed days are one-based half-open intervals. The exact $132/$30/$102 fixture now passes, including $72 in day 1 and $60 income/$30 wages in day 2. The old pending key-mapping request is resolved for the backend; UI display remains unreviewed.

### Real attached-service evidence

The `backend` section uses six **validated actual cabins** plus real café/sunbeds/court and one genuinely hired cleaner. It runs 1,200 shared simulation seconds with no injected activities, tickets or payments. It observed:

- Peak **12 live people, 11 accommodated people, six concurrently booked cabins**; completed 1-, 2- and 3-night stays.
- 16 paid meals, 15 paid lounger admissions and two paid volleyball admissions. Every observed new activity receipt had an actual ready ticket, paid session and guest position at the measured fixture. No reserve/money/booking invariant failed. Global income matches W1 counters and payroll matches the ledger throughout; one cleaner received exactly six $30 wages.
- A real queue, visit-generated dirt (maximum three concurrent mess records with a cleaner), actual cleaning and the **same party** splitting and later rejoining at overnight return. All five first-observed snapshots were captured from the real runtime: split at 69s, cleaning at 138.5s, queue at 186s, meal at 209s, checkout at 258s.
- For each snapshot, raw snapshot restore and JSON restore both accepted, immediate full-envelope equality passed, and the next 40 seconds agreed between a raw-snapshot-restored control advanced in one call and a JSON-restored branch advanced at 1/30. This is backend serialization/step equivalence, not a claim that an actual restarted UI scene or uninterrupted original world was tested.

Natural traffic in that seed paired same-party volleyball players. The separate `backend-court` fixture removes other paid leisure before configure and controls **needs/interests only**: one sport-hungry member per party, companions urgently tired. Actual `choose`, routes, tickets, arrivals and charges run unchanged. A cross-party rally was observed at **911.7333s, people 40 and 48**, on opposite measured sides, both ready and independently charged $10. This is a backend behavior proof, not GPU/ball/motion or latency approval.

### New independent defects for coordinator-owned wrapper

All three were reproduced twice, with a valid positive-control envelope first. Their service snapshots are individually well-formed and checksum-valid; exact aggregate income/wages are preserved. `LivingResortRuntime.restore()` currently returns true and replaces the open state. The acceptance contract requires cross-reference validation before replacement.

**[P1] Required live facility ownership is only checked in one direction.**

- Call site: `scripts/simulation/living_resort_runtime.gd:156`, `_cross_validate()` ticket loop. It verifies ticket → person, but does not require a valid corresponding ticket for every person still approaching/queued/using/exiting a facility (including physically held expired claims where appropriate).
- Actual valid source: six-cabin fixture, seed 8147, **209s**. Person **8**, party **4**, is **eating**, paid, in café **7**, measured slot **1**. The facility service has its active matching ticket.
- Mutation: replace only `facilities.tickets` with `[]`. Standalone `FacilitySessions.restore()` correctly accepts its otherwise-valid empty state; the full wrapper must reject it because the simulation still contains the live paid user. Actual result: wrapper accepts and removes the required reservation from the open runtime.
- Reproducer: `artifacts/worker-6-backend-accepted-missing-live-tickets.json`, keys `valid` and `malformed`. No placement/layout differences.

**[P2] Ledger payer metadata can disagree with retained activity receipts.**

- Call site: `scripts/simulation/living_resort_runtime.gd:166` and `:174`, where validation reconciles aggregates and timestamps but not retained receipt identity/amount/kind/owner fields.
- Same real 209s positive-control source. Rebuild the ledger via its **public `record()`** interface, changing only event `resort:activity:1:1` (`sunbathe`, +$8, party 1, time 83.3333) to `person_id:999999`. Keep ID, time, kind, amount and all totals unchanged. The actual retained person and W1 party receipt still identify person 1; 999999 never existed.
- Actual result: checksum-valid journal and full wrapper accept the nonexistent payer; the invalid journal replaces open state.
- Reproducer: `artifacts/worker-6-backend-accepted-orphan-ledger-person.json`.

**[P2] A wage receipt can reference staff that never existed.**

- Same aggregate-only journal loop. Valid natural snapshot at **1200s** contains one hired staff ID 1 and $180 lifetime payroll.
- Rebuild journal through public `record()`, changing only `staff_id` of `staff:wage:1:1` (-$30, 180s) to **999999**, beyond cleanliness `next_staff_id`. Its own receipt ID still names 1. Totals/hash otherwise valid.
- Actual result: full wrapper accepts the impossible staff identity and replaces the valid journal.
- Reproducer: `artifacts/worker-6-backend-accepted-orphan-ledger-staff.json`.

Historical journals legitimately contain departed/pruned guests and dismissed staff; do not reject every ID absent from today's live roster. Reconcile retained-party receipts exactly, validate canonical event identity and historical ID bounds, and preserve legitimate legacy opening totals/retired aggregates. Coordinator owns the fix; W6 changed no production code and did not weaken tests.

### Fast reproduction / verification

The real valid/malformed pairs already exist, so a fix can be checked in about two seconds without rerunning the 1,200-second sample:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\PROJECTS\Resortis - 31-10-26' --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\worker-6-backend-reject.log' --script res://tests/living_resort_checks.gd -- --only=backend-reject
```

Expected after fixing wrapper: all positive controls restore, all three malformed envelopes return false, and the full open state is unchanged. For a new independent natural run use `--only=backend`; for actual controlled court behavior use `--only=backend-court`. Tests record module SHA-256 at process start because W1/W5 were still editing concurrently. The observed wrapper hash was `5e428739560af2083a2c473eba9db9b7b39df46e63c84b6bbfe7770f61ea3413`.

### Scope remaining / coordination

- The coordinator's exact 240s → JSON → 40s person-4 drift and full legacy `legacy_income_income` issue remain assigned to W1/W5. This turn did not duplicate their fixes or close their exact repros; direct legacy and five *different* backend snapshots passing do not close them. Keep `tests/living_save_checks.gd` owned by coordinator.
- Default-world/UI/GPU groups were **not run** this turn, as requested. Staff bake/import and UI handoff are prerequisites. No screenshots, art acceptance, real rendered crowd profile or global acceptance are claimed. Backend customer counts are simulation counts, not frame-rate measurements.
- Backend local dirt/recovery and job/wage service tests pass. A sustained dirty-area warning/recovery in the actual combined world, actual management signals/picking/follow for all guests, occupied edits at UI call sites, full FPS/speed matrix and real file-level migration/resume remain for the resumed full-world audit/coordinator tests.
- All four protected player-save presence/hash records match their pre-run state in every report: workspace files absent, existing direct-play save/backups unchanged. No production files, other workers' files, shared imports/bakes, source approval or player saves were written.

## Historical wave-1 handoff

Date: 2026-11-01, Asia/Karachi. **Preparation complete; integrated acceptance pending.** Finish this worker chat after this handoff; resume it explicitly when wave 2 is integrated. No additional chats/agents/worktrees were created.

## Owned deliverables

- `docs/plans/living-resort-qa.md`: concrete independent acceptance cases, expected money/day-boundary results, real call sites, evidence rules, commands and pending wave-2 review. Separates encoded automatic checks from scenarios which still require integrated observation, snapshot adapters and visual review.
- `tests/living_resort_checks.gd` (and engine-generated `.uid`): focused/combined `SceneTree` harness. Dynamic loads for W1–W5 modules; missing implementations produce pending cases, existing unparseable modules fail. Tests public profile/decision APIs, real validated six-cabin fixture, population/money/reserve invariants, snapshot rejection/transactionality, facility/FIFO/physical tickets, cross-party court, mess/jobs/wages, event deduplication and legacy import. The default-scene group uses actual `living.simulation` and `living.capture()`, actual Save/pause/speeds/edit/undo controls, isolated startup and schema-4 envelope discovery. It refuses `--workspace-data`/`--fresh` and detects changes to both player save locations/backups.
- `tools/capture_living_resort.gd` (and engine-generated `.uid`): actual-world GPU capture and measured rendered 1x sample. Conditions `crowd`, `queue`, `meal`, `volleyball`, `cleaning`, `split`, `sleeping`. Never fabricates actors, room bookings, dirt or reservations. A cleaning run hires one real cleaner. Crowd sample counts accommodated customers and active bookings, not ambient actors or merely people in a wait. Captures overview/closeup and records renderer, frame intervals, world CPU, draw calls/memory and population minimum/maximum. Headless/missing/unobserved/under-populated scenarios remain pending.
- Evidence files under `artifacts`, described below. No production files, shared scenes/saves, accepted guest art/walking, other workers' tests, shared imports/bakes or reviewed-source records were edited by W6.

## Test result record

All tests used the project-local Godot 4.7.2 console executable and absolute artifact log paths. Coordinator performed class registration; W6 did not run editor import or the full gate. Focused JSON files have `automated_complete: false` and `acceptance_complete: false` even when that section passes.

| Run | Actual result | Evidence under `artifacts/` |
| --- | --- | --- |
| `--prepare-only` after coordinator registration | **Exit 2**, 2 save-safety assertions, 0 failed cases, 1 explicitly pending feature case. Harness compiles and executes. | `living-resort-qa-prepare.log`, `living-resort-checks-prepare.json` |
| `--only=profiles` | **Exit 0**, 1,755 assertions, 0 failed/pending cases. Deterministic 120-party sample, solo/couple, all 1–3 lengths, budgets/interests/variants, force-size API, save safety. | `living-resort-qa-profiles.log`, `living-resort-checks-profiles.json` |
| `--only=brain` (last run after coherent reserve-fixture correction) | **Exit 0**, 11 assertions, 0 failed/pending cases. Urgency choices/free alternative/reserve, actual versus intended recovery, local dirt with healthy needs, warning grace and recovery, save safety. | `living-resort-qa-brain.log`, `living-resort-checks-brain.json` |
| `--only=population` | **Exit 1**, 13 assertions, 1 failed case: current W1 script cannot parse. All ten owned fixture placements validate. **No population runtime, money/resume or scale result is claimed.** | `living-resort-qa-population.log`, `living-resort-checks-population.json` |
| `--only=legacy` | **Exit 1**, 3 assertions, 1 failed case: same W1 parse blocker. **No legacy migration pass is claimed.** | `living-resort-qa-legacy.log`, `living-resort-checks-legacy.json` |
| `--only=world` | **Exit 2**, 2 safety assertions, 0 failed cases, 1 pending: facility service absent. Preflight correctly avoids default-scene startup before wave-2 services exist. No fallback to the legacy fixture. | `living-resort-qa-world.log`, `living-resort-checks-world.json` |
| Capture helper under `--headless` | **Exit 2**, pending; explicitly no PNGs or performance claim. Verifies honest refusal and save preservation. | `living-resort-capture-headless.log`, `living-resort-capture.json` |

Counts include two player-save safety assertions per successful/focused section. Direct-play `user://coastal-layout.json` and `.bak` hashes remained `54bf10e9ad69ce6c36b36c581310c41d71cc6732543053ca3df11004dbab5d0a` and `2331b64c922beee1277ea7508ee42ece78f06b0cc95d0a5c307e8096383981a0`; workspace equivalents were absent and remained absent. Reports contain the full before/after records. The initial registration-blocked preparation artifact is historical, not the clean preparation result; use the suffixed final reports above.

## Immediate blockers observed independently

W1 was still actively implementing during these attempts. Do not confuse this with a final review of a finished handoff. At the latest population run, `res://scripts/simulation/resort_simulation.gd` failed GDScript parsing for inferred local variables:

- line 714 `cell` in `_waiting_point` (loop offset from an untyped Array);
- line 1047 `group`;
- line 1059 `guest`;
- line 1096 `ticket`.

Reproduce with the population command in the QA document (`--only=population`; same executable, no import). These are source type-inference errors after successful class registration, not missing GPU evidence. Coordinator should return them to W1 if still present in the delivered file. W6 did not fix another owner's source or declare booking/migration tests passed. The initial owned fixture lacked the final path cell connecting promenade to beach; W6 fixed that fixture and confirmed all placements validate before reporting this blocker.

## API/integration facts consumed

- Contract APIs are consumed exactly through `configure/advance/inspect/capture/restore`, person/party/money fields, `GuestBrain.choose/advance`, `GuestProfiles.create_party`, facility tickets, cleanliness jobs/events and ledger `record` idempotency. Existing registration/fixtures come from `ResortLayout`, `ResortCatalog`, `GuestMotion`, `GuestActivitySlots`, `GuestStay`.
- Coordinator steering is incorporated: default `CoastalResort.living` wrapper; `living.simulation` plus service fields; `population_view`; `selected_person_id`; schema 4 `live_resort`. Legacy fixture is never enabled by the new suite. Actual default-scene tests assert that ambient `walkers` is empty and real population presentation exists.
- CLI `--only=profiles|brain|population|facilities|cleanliness|ledger|legacy|world`; no `--only` selects all. `--prepare-only` performs readiness/save-safety only. `--allow-pending` is a developer convenience, not acceptance. Unknown sections fail. Combined report is `living-resort-checks.json`; subsets use `living-resort-checks-SECTION.json`; preparation uses `living-resort-checks-prepare.json`. Exit 1 fails; 2 means incomplete; 0 does not imply full acceptance for a subset.
- Capture CLI: `--condition=...`, `--minimum-people=8` (1–12 allowed), `--sample-frames=600` (60–3600 allowed), `--seek-seconds=1200` (0–3600 allowed). Report `living-resort-capture.json` and PNGs `living-resort-CONDITION-overview/closeup.png`; archive each scenario's JSON before the next run. Wall intervals include vsync/OS scheduling and are not GPU execution timings. No performance budget or 100–200-customer promise is invented.

## Requested interface details before wave-2 review

1. **W5/coordinator:** publish concrete `OperatingLedger.inspect()` keys for all-time and per-day income/wages/net and how the UI selects the day. Contract describes totals but does not name those fields. `LEDGER-01` deliberately remains pending after recording fixture expected values ($132 income, $30 wages, $102 net; day 0 +$72, day 1 +$60/-$30) until the actual displayed fields can be asserted. Do not remove pending based solely on an identical round-trip.
2. **W3/W4/coordinator:** publish finalized ticket/job/claim/event snapshot structures. Add exact malformed cross-service cases to this owned harness: orphan/wrong-party tickets, duplicate slot/queue order, double cleaner claim, missing mess/staff, stale target, and ledger totals disagreeing with guest/staff events. The version-1 top envelope alone does not prove cross-validation.
3. **Coordinator:** supply the integrated safe trigger/call site for controlled couple needs at safe decision states, real management action signals, pause/speed control, occupied path/facility edits and restored top-level state. Current known default-world calls already used; do not use `legacy_stay_fixture` to get the new suite green.
4. Clarify the reversible tuning for queue size/timeout, completed stay/archived record retention, dirt cap/rate/cleaning radius/duration, warning thresholds and mid-day hiring/dismissal wage convention. Tests should measure those published rules rather than guess private constants.

## Required follow-through when resumed

- Read all delivered worker modules and actual integrated call sites independently; rerun the two blocked focused sections, then service sections. Adjust only genuine schema adapters; preserve behavioral requirements. Raw logs are authoritative alongside JSON; a test summary cannot override script errors.
- Extend default-world acceptance to observed **mid-queue, meal, split couple, active cleaning and checkout** saves and their future continuation. Compare full `living.capture()` including pending events/service claims, not simulation alone. Add cross-service rejection and actual management-signal/profile/click/follow checks for every identity.
- Exercise café **and sunbed** capacities, joint/split/rejoined couple overnight/checkout behavior, per-person admission charges, cross-party volleyball path/ball behavior, dirty warnings/recovery and dismissal/path-edit job release. Verify redo/late move-commit guards, construction over people/queues/staff, and unrelated allowed edits.
- Run equivalent 30/60/120 FPS and 1x/2x/4x advances across night/wage/arrival/queue boundaries and pause. The current harness contains core equivalence and actual speed/pause checks; the full matrix is not yet run.
- Capture/inspect actual GPU imagery and staff motion at close and normal game size, both cabin facings, all eight protected guest directions and furniture/net/sunbed occlusion. Headless refusal is not GPU proof. Profile a genuine 8–12-customer sample throughout the measurement, with at least four occupied bookings; then high-speed/busy variants.
- Return defects to producing workers through coordinator, recheck focused fixes, and let coordinator run shared regression/art/source approval. Update this handoff/QA document with actual results; no approved feature is accepted from a producing worker's status message.

Wave 1 ends here. No full integrated/visual/performance acceptance is asserted.

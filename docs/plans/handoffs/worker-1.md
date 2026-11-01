# Worker 1 handoff: population, bookings and individual movement

Status: owned implementation complete; final focused suite **592 checks, zero failures**. The coordinator subsequently passed **60 complete schema-4 save integration checks**, including attached-service legacy imports and immediate reload. Default-scene/GPU acceptance, visual review and the broad asset gate remain with the coordinator. No shared scene, legacy fixture, player save, accepted guest art, walking implementation, bake/import or source approval was changed by this worker. No further agents/chats/worktrees were created.

## Owned files

- `scripts/simulation/resort_simulation.gd`: new `ResortSimulation extends RefCounted`.
- `scripts/simulation/booking_registry.gd`: new `BookingRegistry extends RefCounted`.
- `tests/population_checks.gd`: memory-only controller scenarios, including actual W3 service integration when its module exists.
- This handoff. Godot's associated script UID files are derived registration metadata.

## Public interface

All agreed controller methods are implemented with the contract signatures:

`configure(map, library, seed_value=8147)`, `advance(delta)`, `person(id)`, `party(id)`, `activity_slot(person_id)`, `inspect()`, `protects(object_id)`, `access_survives(candidate)`, `layout_changed()`, `capture()`, `restore(data)`, `import_legacy(data)`, `drain_events()`.

Public fields are `layout`, `assets`, `clock`, `people:Array[Dictionary]`, `parties:Array[Dictionary]`, and nullable RefCounted `facilities`, `cleanliness`, `ledger`. Additional useful fields are `bookings`, `population_cap` (default 12), `arrivals_enabled` (default true), `total_room_income`, `total_activity_income`. `reserve(party_dictionary)` returns the party's remaining protected room money. `configure()` resets the population and detaches old service references; configure/attach services afterward.

`BookingRegistry` exposes `configure(map)`, `owner(cabin_id)`, `booking(party_id)`, `protects(cabin_id)`, `reserve(party_id,cabin_id,nights,budget,rate=60)`, `choose(party_id,nights,budget,start=ARRIVAL)`, `release(party_id)`, `capture()`, transactional `restore(data)`. The registry holds exclusive cabin identity, booked nights and immutable rate; it never charges money.

`person()`/`party()` return backing dictionaries for the controller/brain seam. UI should use the detached, flattened `inspect()` view. `inspect()` includes the contract root fields and persistent `mood_reason`/`unhappy_elapsed` alongside route/activity explanations. No new person states were added beyond the agreed list. Internal party states are waiting_room, reserved, active, reuniting, checkout, departing, departed.

## Implemented behavior and tuning

- One 1/30-second fixed clock, with DAY_SECONDS=180. Input remainder is persisted, never discarded. An individual `advance()` processes at most 36,000 steps (1,200 simulated seconds); excess remains pending and can be consumed by subsequent `advance(0)` calls. Zero/negative/nonfinite deltas do not invent elapsed time. Pause should call no advance or advance(0) with no pending skip.
- Each person owns a separate **GuestMotion** and separate needs, profile, activity, history and route. Motion position/direction/distance are authoritative; there is no second person-position field. The snapshot augments the unchanged GuestMotion payload with its `moving` flag for immediate restored presentation.
- Initial party is Maya/Leo, two nights, $480 shared budget. Subsequent arrivals use W2 `GuestProfiles` and the caller-owned persisted RNG, every 20–29 seconds. IDs are monotonic. Maximum nondeparted people is 12, including bounded room waiters; departed person records are bounded to 24, with aggregate retired income retained. Four starter cabins permit at most four resident parties, up to eight resident people when all are couples. The cap is not a claim that every seed reaches twelve accommodated people.
- Cabin selection requires an affordable unreserved room and a real arrival-to-door route. Waiting arrivals have separate reachable logical anchors. Retry is every two seconds; no room after 32 seconds produces an explained departure without charges. New waiting anchors avoid live/held facility stations as well as existing room waiters and entrances.
- Actual cabin entry/exit follows the existing **CabinInterior.aisle** in each facing and the exact role-0/role-1 sleeping fixtures. People can split their daytime routes and activities. A party reunites at its own cabin starting 65 seconds before its next room deadline, or after a confirmed early-departure request. Room payment/check-out waits until all members are sleeping there. Reservation release waits until every member physically exits to departing/departed; one partner cannot leave a reserved room orphaned.
- First room charge occurs once all members check in, then once per night at the preserved deadline while reunited. Rate remains **$60 per cabin/night**, shared by the party. Ordinary activity spending cannot use the remaining night reserve. Night counts 1–3 finish through the same reunion/departure lifecycle.
- Activity fees remain meal $12, sunbathe $8, volleyball $10 **per person**, charged only at the actual fixture and ready admission. Volleyball validates all players' combined per-party affordability before charging either player, including cross-party matches. If either cannot pay, both leave without a fee. Admitted players activate together, at opposite actual facility claim indices, irrespective of their party bed role.
- W2 advances needs only in actual states. The decision seam supplies real reachable offers, queue counts, `booking_rate`, current room reserve, last activity and the shared budget. Safe W3 `should_join()` invitations can coordinate leisure; urgent individual needs still win. Failed/expired visits receive a bounded retry cooldown; unpaired court waits end without payment.
- Outdoor movement uses navigation to the queue station/entrance, then the exact fixture approach. Fractional Vector2 queue endpoints are appended after the grid route and serialized exactly. Promotion while walking to an old queue station first replans through outdoor navigation to the actual door. It does not cut directly through scenery.
- Cancellation during a partial fixture approach retreats through only the **already traversed prefix**, starting toward the previous waypoint. Persisted `exit_prefix` validates that shortened exit route. A held ticket is released only after the physical exit. Night reunion can use that same immediate retreat.
- Protection covers all cabin reservations, committed facility users/tickets, current outdoor access, interior exit access, facility waiting stations and attached service protections. Protected objects must retain identity, kind, position and facing in a proposed layout. `layout_changed()` replans affected outdoor routes and notifies attached services.

## Services, money and optional dependencies

No W3/W4/W5 file is required at parse time. W2 profiles/brain and W3 party suggestions are loaded by path when present. With W2 absent, the lodging base has deterministic simple needs/choices; the final integrated game should use the delivered W2 modules.

Attach the configured W3 service **before advancing fresh runtime**. W1 then delegates claims/admission/queues to W3 and keeps its internal ticket list empty. `inspect.available` is honored, including a full asset that can still accept into a safe bounded queue. Actual slot index, rather than party role, drives facility fixtures.

For standalone operation and old mid-activity migration, the controller also supports an internal two-place/four-waiter capacity fallback, exact fixture approaches, FIFO promotion, paired court admission and bounded waits. This is not advanced alongside duplicate external claims. Matching complete external claims reconstructed by the wrapper are adopted read-only at the next advance. Otherwise an imported local visit can finish safely; when internal claims drain, the next fixed step switches to W3, including within one long advance.

**W1 advances every attached facility/cleanliness service exactly once per shared step**, even while an imported local visit is finishing. Order: arrivals, facility service/local admission housekeeping, cleanliness, party deadlines/reunion requests, individual needs/movement/transitions, completed party transitions, wage/event delivery. Do not additionally advance services from world wiring.

Money events have stable IDs `resort:room:<party>:<night>` and `resort:activity:<person>:<visit>`. A visit's `session_paid`, receipts and notification marker persist. Without a ledger, new financial events remain in the snapshot until `drain_events()`. With a ledger, they are recorded directly once, relying on its idempotent IDs; cleanliness wage events are drained after the same step and delivered through that ledger. A completed/ended paid visit notifies attached cleanliness once. No player-file I/O occurs in this module.

`layout_changed()` already calls facilities.layout_changed (when provided) and cleanliness.layout_changed. **Shared-wrapper follow-up:** remove a duplicate direct cleanliness.layout_changed call if it also invokes simulation.layout_changed. The wrapper's extra access_survives cleanliness check is redundant but read-only.

## Snapshot and legacy mapping

Simulation snapshot version 1 is JSON-safe and includes profiles, all person/party state, room registry, routes/indices/distance/heading/moving/delay, activity clocks and timers, approach/exit prefixes, deadlines, RNG, next IDs/arrival, internal claims, receipts, pending events, population settings and retained/retired income. RNG seed/state are decimal strings, preserving signed 64-bit values through JSON. `clock_origin` preserves a legacy substep offset rather than rounding its old clock or deadlines.

`restore()` stages candidates and validates before changing the live controller: finite integral numeric identities/money, duplicate members/roles/rooms/slots/events, money conservation and receipts, matching reservations, profile/needs/mood fields, valid outdoor routes, exact registered cabin/fixture approaches and allowed partial exits, queue positions and event-to-money correspondence. The snapshot does not embed layout/assets or other service snapshots. The coordinator's envelope must atomically restore/cross-validate those services, ownership and journal totals. Restored `sessions_external=true` waits for service attachment before moving time; it never silently invents replacement claims.

`import_legacy()` first validates via unchanged GuestStay.restore, with stronger integer/index validation before calling it. It preserves the old solo/couple budget, initial budget (240*size), room/activity spending, paid nights, booked cabin/rate, exact next-night deadline, primary and companion positions/routes/indices/distance/direction, and current activity/timer/elapsed clock. Old nonpositive unused timers are clamped to zero; legacy transient moving is reconstructed from unfinished route/delay.

State mapping:

| Legacy | New person state |
| --- | --- |
| arriving / waiting | arriving / waiting_room |
| to_cabin / entering / exiting / returning / departing / departed | Same state |
| resting / overnight | sleeping; original timer/deadline retained |
| to_cafe / to_beach / to_court | to_facility, with the original target/activity |
| approaching_seats / approaching_loungers / approaching_court | approaching_activity |
| sitting / eating | Same state |
| relaxing / playing_volleyball | lying / volleyball |
| leaving_seats / leaving_loungers / leaving_court | leaving_activity with complete legacy exit prefix |

Party mapping distinguishes reserved first entry, daytime active rest, overnight reunion, physical checkout and departed records. In-progress old facility claims use the original role's exact fixture. Old fees paid before the legacy approach remain `session_paid=true`, so reaching the new admitted pose cannot charge them again. Original activity income is kept in `legacy_activity_spent`, separate from new receipts; no unsupported historical category/timestamp is invented.

**Historical income is never emitted by import.** Seed the ledger once in the outer wrapper from preserved room/activity totals, as requested by the coordinator. New future payments alone enter pending events.

Legacy envelope contracts:

1. **Clock initialization is now implemented and verified by the coordinator.** The wrapper sets the otherwise-fresh facility/cleanliness service clocks to the imported clock before immediate cross-validation/save, using zero-delta service advances. This reconstructs an empty service epoch without replaying historical mess/payroll. W1 deliberately does not mutate those services during transactional import. Preserve this wrapper behavior, including for old saves with no current facility.
2. If reconstructing external facility claims, keep both old role/slot assignments and include every currently committed imported person. Matching complete claims are adopted automatically; do not create a partial second set. An empty external service may instead coexist while the imported local visit finishes; its clock still advances once per W1 step and ownership then switches to W3.
3. Both imported people retain the old shared activity_elapsed value. Preserve the old opposite-side presentation offset using **actual court slot** (the old world used +2 seconds for the second volleyball side and +0.2 for other companion poses). New court players activate at the same admission clock. Actor/ball presentation belongs to the coordinator.

## Save/resume precision diagnosis

The coordinator's actual combined-services repro failed at person 4: `(12.24,22)` uninterrupted versus `(12.20,22)` resumed, one movement step. It reproduced in a reduced simulation with no cleanliness, staff or ledger, using default JSON formatting.

Tagged temporary instrumentation isolated the first difference at clock 241.56666666666666: `sleep_until` rounded from **241.56666666666666 to 241.566666666667**. Strict comparison kept the resumed person asleep one extra step. It was a deadline boundary error, not a different route, RNG, need or global tick count.

The fix centralizes absolute time comparisons in `_time_reached()` with a one-microsecond serialization allowance, consistent with W3's time comparisons, and clamps sub-microsecond countdown residue to zero. No position-test tolerance was relaxed. Production-format default JSON continuation is now a permanent regression, in addition to full-precision capture/resume tests. Tagged instrumentation and the temporary trace mode/helper have been removed. The diagnostic log is under artifacts; no debug authoring file remains.

## Verification and limits

Project-local Godot 4.7.2, no editor import or broad gate, no world startup/player-save writes in owned tests:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/population_checks.gd --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\population-checks.log'
```

**Final: `POPULATION_CHECKS 592 checks; 0 failures`, exit 0.**

Coverage includes concurrent unique rooms, cap/replenishment/bounded records, varied profiles/nights, first-party continuity, all money/reserves/events, 1–3 complete nights in both cabin facings, physical reunion/release, real café queues and no premature fees, lone/two-player court admission, one-fee couple rejection, cross-party recheck, fractional endpoints, partial retreat, protected edits, no-room waits/recovery, whole-population mid-state JSON/RNG continuation, default-precision JSON, 60Hz/4x equivalence, malformed transactional restores, optional mood validation, pending-ledger idempotency, service once-per-step clocks, actual W3 active/queued/exit resume, and local legacy-to-W3 ownership transfer. Legacy v1 solo/v2 solo/couple fixtures in both facings import at their real activity/movement phases without losing money or emitting historical events.

Focused admission/integration mode: `-- --focus-admission`, **34 checks, 0 failures** (`artifacts/population-admission-checks.log`). Default-format resume mode: `-- --focus-resume`, **37 checks, 0 failures** (`artifacts/population-precision-checks.log`). The complete 592-check run includes both groups.

Coordinator's original actual combined-service regression was rerun unchanged:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/living_save_checks.gd --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\population-resume-repro.log' -- --resume-only
```

**`LIVING_SAVE_RESUME_CHECKS 21 failures=[]`, exit 0.** This includes a real hired cleaner, ledger, population and W3 through 240+40 seconds versus JSON restore plus 1,200 steps.

The coordinator subsequently ran the complete `tests/living_save_checks.gd` suite after the controller and W5 ledger fixes. Verified log: `artifacts/living-save-integration.log`, **`LIVING_SAVE_CHECKS 60 failures=[]`**. This covers complete-service JSON continuation, real schema-4 save/load transactionality, forged-income rejection, old mid-activity imports with attached services, immediate migrated reload, and once-only historical income. The worker inspected that final log; this was the coordinator's run, not an additional worker broad gate.

No claim of final visual approval, staff artwork acceptance, broad regression success, production performance or full UI acceptance is made here. New movement reuses the protected art, exact aisles/fixtures and GuestMotion unchanged; actual in-game render/occlusion/ball-phase review still belongs in integrated acceptance. The shared-wrapper duplicate layout_changed notification noted above remains a coordinator cleanup item. Owned focused checks, cleanup and handoff are finished.

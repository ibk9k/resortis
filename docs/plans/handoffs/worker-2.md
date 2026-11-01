# Worker 2 handoff: guest decisions and profiles

Status: owned modules implemented and focused checks pass. Integrated gameplay, UI presentation and legacy/world regressions still require coordinator acceptance. No other worker's files, shared scenes, GuestStay, guest artwork, walking code or player saves were edited. No editor import, bake, source approval or full gate was run by this worker.

## Files and APIs

- `scripts/simulation/guest_profiles.gd`: `class_name GuestProfiles`, `extends RefCounted`.
  - `static create_party(rng:RandomNumberGenerator, party_id:int, size:int=0)->Dictionary` returns exactly `{nights,budget,members}`. `members` contains the required profile dictionaries, with separate mutable need/interest data.
  - Size 0 chooses uniformly between one and two people; explicit supported sizes are honoured. Nights vary uniformly from 1–3. All random draws use the supplied RNG; its seed is never changed, and no global RNG is used. The caller assigns identities and handles Maya/Leo continuity.
  - Budgets cover shared lodging at $60/night plus per-person daily allowances drawn from modest ($22–30), medium ($36–48) or generous ($54–70) ranges, plus an $8–24 per-person buffer. These are ordinary reserve-protecting guests; no carefree spending exception is generated.
  - Each member has 2–3 unique interests from `Beach walks`, `Good food`, `Sunbathing`, `Volleyball`, `Quiet time`. Companions share one interest but draw independent other interests and needs. Names are distinct within a party; either accepted female/male appearance can be chosen for each role.
  - Initial satisfied-need ranges: hunger 42–88, rest 38–86, enjoyment 35–78. Higher values mean more satisfied, matching legacy GuestStay.
- `scripts/simulation/guest_brain.gd`: `class_name GuestBrain`, `extends RefCounted`.
  - `static advance(person:Dictionary, delta:float, cleanliness_score:float=100.0)->void` updates needs, mood, warning/departure state and human-readable explanations/history. It never moves a person, modifies a party, spends money, reserves a room or admits a facility user.
  - `static choose(person:Dictionary, party:Dictionary, available:Array[Dictionary], clock:float)->Dictionary` returns exactly `{activity,facility_id,reason}`. All five contract activities are supported. Rest/stroll use facility ID -1. It neither mutates its inputs nor performs payments.
  - Urgent hunger (<=30) or rest (<=25) overrides leisure; when both are urgent the lower fraction of its threshold wins. Unavailable/unaffordable meals produce a free stroll or useful cabin rest, rather than another unrelated paid activity. Leisure scoring considers interests, current needs, walking distance, queue length, price and previous activity. Ties are stable across offer order and clock values.
  - Spending is limited to `budget - (nights-paid_nights)*booking_rate`; booking_rate is optional and defaults to $60. The reserve is shared per party, not multiplied for couples. Malformed/fractional/nonfinite money, stay and facility integer fields cannot enable paid purchases; JSON integral floats remain valid.
  - Already committed tasks retain their intent until the controller completes/cancels them. Optional W1 `last_activity` is recognised after `activity` is cleared at a safe decision state; otherwise the current activity supplies the repetition hint. The controller owns activity duration and decision cooldown.
- `tests/guest_decision_checks.gd`: pure deterministic rule scenarios. No world scene is started and no layout/player save is opened or written. The motion fixture is deliberately null because these APIs never access it. Tests preload the two new scripts directly, so no new global class import is needed for this test.

## Need and mood tuning

Rates below are satisfied-need points per simulation second; a day is the shared 180-second day. Recovery depends on actual `person.state`, never `person.activity` alone.

| Actual state | Hunger | Rest | Enjoyment |
| --- | ---: | ---: | ---: |
| Default/deciding/sitting | -0.20 | -0.12 | -0.18 |
| Travelling/entering/exiting/approaching/leaving | -0.22 | -0.15 | -0.10 |
| Queueing/waiting for room or partner | -0.20 | -0.12 | -0.25 |
| Eating | +4.50 | -0.07 | +0.65 for food interest, otherwise +0.25 |
| Sleeping | -0.12 | +2.40 | -0.02 |
| Lying on a lounger | -0.16 | +0.50 | +2.80 for sunbathing interest, otherwise +1.90 |
| Volleyball | -0.28 | -0.45 | +3.50 for volleyball interest, otherwise +2.30 |
| Strolling | -0.22 | -0.16 | +1.10 for beach-walk interest, otherwise +0.65 |

Needs/mood clamp to 0–100. Departed guests freeze. Zero, negative and nonfinite deltas are no-ops.

Mood is 40% hunger + 35% rest + 25% enjoyment, minus a vital-need penalty of `1.4*max(0,25-min(hunger,rest))`, minus a separate local-dirt penalty of `0.65*(100-cleanliness_score)`. Cleanliness never changes hunger/rest/enjoyment. Mood responds to current conditions; it has no independent smoothing clock.

Mood <=28 for **18 continuous simulation seconds** produces an explained early-checkout warning. After that, **30 more seconds of severe mood** set `want_leave`. Intermediate mood (28–43) pauses an active warning's failure timer; before a warning, improvement above 28 resets the pre-warning interval. Mood >=43 cancels the warning and both timers and records recovery. Thus uninterrupted severe failure first requests checkout after 48 seconds. Once `want_leave` is set the controller should carry out checkout; the warning cannot reverse an already committed departure.

Need clamp events, the hunger/rest minimum crossing and mood thresholds are integrated analytically. Needs remain 64-bit GDScript scalar numbers; using Vector3 for storage caused measurable time-step drift and was corrected. Complaint history evaluates the cause at the actual warning/departure boundary. The final live code uses array indexing (`start[0]`, `start[1]`, etc.), including the hunger/rest crossing path; there are no remaining `.x`/`.y` accesses from the intermediate Vector3 version.

## Persistence and integration instructions

1. Call `GuestBrain.advance` once per person per shared simulation step with cleanliness at `person.motion.position` (or 100 without a cleanliness service). Keep state transitions in W1; moving toward a meal must remain `to_facility`/`approaching_activity` until eating actually starts.
2. Call `choose` only at W1's safe deciding seam. Supply reachable facilities and real queue/admission availability. An available queued facility may be selected, but long queues reduce its utility. W3 still owns partner matching, admission and bounded wait cancellation. W1 must recheck affordability on admission because two partners can choose against the same shared budget.
3. Preserve new optional person fields **`unhappy_elapsed:float`** (0–18) and **`mood_reason:String`** in snapshots. `warning_elapsed` is the elapsed post-warning severe time (0–30), not the pre-warning interval. History is bounded to the most recent 12 entries. Missing optional fields naturally start at zero/are recomputed for legacy imports.
4. **Coordinator/W1 follow-up requested:** W1's current capture duplicates each whole person, which preserves these additions. Extend transactional `_valid_person` restoration to validate optional `unhappy_elapsed` as finite 0–18 and `mood_reason` as a bounded string before replacement. W2 has not edited W1's validator. Add malformed-field restore scenarios in integration QA.
5. **UI integration follow-up requested:** expose `mood_reason` in inspect output, or compose the active warning explanation from it plus `warning_elapsed`. Ordinary route/activity reasons may be overwritten by W1 after the warning edge; the persistent local complaint should remain visible while the warning is active. No mandatory public method signature change is required.
6. W1 currently supplies an explicit `booking_rate` in the spending view and recognises the new scripts through its optional loader, so its room-rate and loading seams already match this API. Keep first-party Maya/Leo/$480/two-night continuity in W1.

## Validation and remaining limits

Focused run, project-local Godot 4.7.2:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\PROJECTS\Resortis - 31-10-26' --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\guest-decision-checks.log' --script 'res://tests/guest_decision_checks.gd'
```

**Result: `GUEST_DECISION_CHECKS 668 checks; 0 failures`, exit 0.** The absolute log is `artifacts/guest-decision-checks.log`.

Coverage: 64 deterministic generated parties and caller-RNG continuation; forced solo/couple sizes; independent profiles; fixed interest-driven choices; urgent-needs priorities; reserve/payment boundaries including alternate room rates; unavailable facilities; queue/distance/tie ordering; malformed JSON numeric fields; no payment/input mutation during choice; actual-state-only recovery; dirt separate from needs; delayed warning/grace/recovery/repeated bad spells; JSON continuation of warning timers; exact grace threshold; normal 60 Hz, coarse 4x-sized and single elapsed updates; 72 fixed-profile/state/cleanliness combinations covering need/mood crossings and clamps.

The first run encountered a concurrent shared `LivingResortRuntime` registration dependency through the unused GuestMotion test fixture. The fixture now has no world dependency, and the final run has no parse/registration errors. No import remains necessary for this focused script; normal shared editor import remains the coordinator's responsibility.

No visual claim is made: W1/W3 integration still needs actual cabin rest, seated meal/lounger/game admission and locomotion checks, timed 1–3-night runs, split/rejoined companions, and UI warning recovery evidence. Balance values are reversible defaults and need the coordinator's in-game acceptance. Existing broad legacy/asset gates were intentionally not run during concurrent work.

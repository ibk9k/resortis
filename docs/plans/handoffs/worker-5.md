# Worker 5 handoff — management panels and operating ledger

Date: 2026-11-01, Asia/Karachi. Implementation handed off for independent coordinator review. Only W5-owned production/test files and this handoff were edited. No additional agents/chats, world/HUD wiring, other workers' sources, player saves, guest art/walking, imports, bakes, full gates or source approval were changed/run.

## Files delivered

- `scripts/simulation/operating_ledger.gd`: `class_name OperatingLedger`, `RefCounted`.
- `scripts/ui/resort_management_ui.gd`: `class_name ResortManagementUI`, `CanvasLayer`.
- `tests/management_checks.gd`: focused ledger and isolated sample-view UI checks; optional native captures.
- This handoff. Generated logs and eight sample screenshots are under `artifacts/worker-5-*`.

The impeccable skill was applied using existing `PRODUCT.md`, `DESIGN.md`, the product register and `resort_hud.gd`. The existing forest-green, cream, sage, gold and mint palette, 4px corners, Noto Sans/default font and visible keyboard focus were retained. Eight text/background combinations pass a calculated 4.5:1 contrast check. No design-system files were edited.

## Ledger API and semantics

The contract API is implemented: `record(event:Dictionary)->bool`, `inspect(clock:float)->Dictionary`, `capture()->Dictionary`, `restore(data:Dictionary)->bool`.

`record` accepts room/meal/sunbathe/volleyball/legacy_income as positive nonzero income and wage as negative nonzero expense. Required fields are `id`, `kind`, `amount`, `time`; optional `party_id`, `person_id`, `staff_id` are nonnegative integers. Zero identity sentinels are allowed. Unknown event fields, objects, missing fields, bad kinds/signs, empty/control-containing/edge-padded IDs, fractional/nonfinite/boolean/string money or identities, and negative/nonfinite timestamps are rejected. Integral JSON floats normalize to integers. Rejected events and duplicate IDs return false without any change. Validation happens before duplicate lookup, including malformed duplicate receipts. No charge, guest budget, staffing or construction state is owned here.

Every accepted ID is retained in an append-only audit journal. Late/out-of-order delivery is supported; the original event timestamp chooses its day. Days are **one-based half-open intervals**: day 1 is `[0,180)`, day 2 is `[180,360)`. Therefore a wage emitted exactly at 180 seconds is recorded on day 2, alongside a room event at the same timestamp. There is no fuzzy boundary tolerance. Inspect does not advance time or create events.

Inspect fields:

| Field | Meaning |
| --- | --- |
| `income_total` | Lifetime positive room and all activity income, including `legacy_income` |
| `wages_total` | Lifetime positive wage expense; the journal wage amounts remain negative |
| `net_total` | `income_total - wages_total` |
| `today_income`, `today_wages`, `today_net` | Same signs/meaning for the requested clock's day |
| `day` | One-based simulation day |
| `days:Array[Dictionary]` | Ascending days with recorded events plus the requested current day, even when empty |
| `room_income` | Lifetime room income |
| `activity_income` | Lifetime meal + sunbathe + volleyball + legacy activity income |
| `meal_income`, `sunbathe_income`, `volleyball_income`, `legacy_income` | Lifetime individual income categories |
| `event_count` | Number of accepted unique receipts |
| `last_event_time` | Maximum recorded timestamp, cached for cheap live inspection; zero for an empty ledger |

Each daily row contains `day`, `start_time`, `end_time`, `income`, `wages` (positive expense), `net`, `room_income`, `activity_income`, `meal_income`, `sunbathe_income`, `volleyball_income`, `legacy_income`, `event_count`. Missing empty historical days are intentionally sparse; no unbounded range is allocated for a large query clock. Lifetime totals include every recorded receipt; inspect does not filter committed events out when queried with an earlier clock.

`capture` produces JSON-safe `{version:1,events:Array[Dictionary],income_total:int,wages_total:int,net_total:int,journal_hash:String}`. No native objects/vectors or opaque aggregate-only replacement are used. Capture and inspect return detached nested containers. Restore requires this complete schema, reconstructs every receipt into a candidate, rejects duplicate IDs or malformed entries, recomputes totals and verifies the canonical SHA-256 journal checksum before replacing any live state. The checksum detects journal edits/order changes; it is an integrity checksum, not an authentication mechanism. JSON object key order and integral-number representation do not alter the normalized journal.

Money and identity values/totals are limited to exact JSON-safe integers, ±9,007,199,254,740,991 (identities nonnegative). A journal has a defensive maximum of 250,000 receipts; recording beyond it returns false. This is a finite proof-scale limit, not journal compaction. `record` has no supplied current clock, so it validates the event timestamp's shape but cannot establish that the event has already happened in the simulation.

The coordinator-reported legacy-income bug is fixed: `legacy_income` now updates the daily **`legacy_income`** field, rather than looking up nonexistent `legacy_income_income`. Focused tests exercise the exact runtime opening IDs `import-1-room`/`import-1-legacy_income`, JSON restore, duplicate import suppression and a subsequent new meal. Historical activity income stays unclassified rather than being invented as meals. Opening entries use the timestamp supplied by the wrapper; old saves cannot provide original activity dates. Their daily summary is an opening entry on the import day.

## Management UI API and live mapping

Public methods match current root wiring: `build()` (idempotent), `refresh(view)`, `show_section("guests"|"facilities"|"staff"|"operations")`, `close()`. `action_requested(action:String,id:int)` emits only the contract intents: `select_guest`, `follow_guest`, `hire_janitor` (0), `dismiss_janitor`, `close` (0). Programmatic close is silent; the close button/Esc hides and emits close. Follow and staff buttons never directly call a simulation/service or alter the supplied inspect view.

The CanvasLayer is layer 2, above the existing HUD. Its full-screen root ignores mouse input outside the right-hand management panel. The panel starts at logical y=94, ends 184px above the viewport bottom, and is at most 600px wide. It preserves access to the top bar and building tray. Minimum-size changes after wrapped text settles trigger a deferred refit; this fixes first-open panel expansion. Actual focused layout checks cover all four sections at 1440×900, 1280×720, 1024×640 and 960×600.

All section controls are built once. Guest/facility/staff/day rows are keyed by actual model ID/day and only added/removed when those identities change. Refresh neither rebuilds the tree nor resets scrolling, selection or focused buttons. Each section retains its scroll on navigation. Clicking a guest intentionally returns their profile to the top; a background 5 Hz refresh does not. Below 540px panel width, an `All guests`/`Profile` control switches the guest list and profile into the same available space; wide panels display both together. Compact windows hide the repeated day subtitle to preserve reading space.

| Panel | Exact input mapping and displayed behavior |
| --- | --- |
| Shared | `clock` supplies the one-based day subtitle. Root's `selected_person_id` and `following` govern selection and Follow/Stop following. If no selected ID exists, the first active person is displayed without creating a model selection or emitting an unsolicited action. |
| Guests | `people[].id/name/state` supply stable, individually selectable rows. Active people with distinct positive `cabin_id`s determine the guest/cabin count. `needs.hunger/rest/enjoyment` are satisfaction percentages, labeled Food/Rest/Enjoyment with higher-is-better tooltips; `mood` is shown separately. |
| Guest profile | `reason` and optional `mood_reason` explain current choices/complaints. `warning_elapsed`, optional `unhappy_elapsed`, `want_leave` provide a visible departure warning and remaining grace; current W2 defaults are 18s sustained unhappiness and 30s grace. Warning status is also in the list. Recovery from the root removes it. `nights`, `paid_nights`, `cabin_id`, `partner_id`, `interests`, and the last four `history` strings describe the stay. `budget`/`reserve` are explicitly the party's shared budget and unpaid-room reserve; activity money is their nonnegative difference. No money is charged or transferred by this calculation. |
| Facilities | W3 `id/name/kind/price/capacity/occupancy/occupants`, `active`, `reserved`, `exiting`, `queue/queue_count/queue_limit`, `reachable`, `available`. Held physical places are distinguished from active use and approaching/exiting people. FIFO queue IDs resolve to guest names. Full queues, blocked entrances, lack of safe waiting ground and volleyball waiting for both players have plain explanations. |
| Staff | `cleanliness.cleanliness`, `mess_count`, `staff`, `hired_count`, `max_staff`, `daily_wage`. The default $30 recurring wage, no hiring fee, current total daily payroll and three-person limit are explicit. Hire disables at the real limit or with no service data. `staff[].id/name/state/daily_wage/progress/cleaned_count/reason` supplies keyed rows and dismiss intents. `mess[].kind/facility_id/claimed_by` gives tasks with janitor assignments. Positions are not reinterpreted or stored in another simulation. |
| Results | `operations.day`, the required lifetime/today totals and `days` supply the summary. Category rows use lifetime `*_income` and the matching current daily row's category fields. Wages display with a minus sign while the input remains positive expense. Net is signed. `legacy_income` is labeled Earlier activities with an older-save provenance tooltip and hidden when zero. Daily history uses each row's exact income/wages/net, latest day first. |

The UI uses inspect dictionaries only. Its cached view, row references, section choice and compact disclosure are presentation state, not a second population, budget, payroll or queue model. Existing speeds/pause are not intercepted; UI only consumes its own Esc close.

## Verification and evidence

Project-local Godot 4.7.2 was used with absolute logs. No world scene or player save is started by the focused W5 suite; UI tests use their own SubViewport and sample dictionaries. Both workspace and direct-play saves plus `.bak` are hashed before and after.

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\PROJECTS\Resortis - 31-10-26' --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\worker-5-management-checks.log' --script 'res://tests/management_checks.gd'
```

Final result: **`MANAGEMENT_CHECKS 253 checks; 0 failures`, exit 0.** Covers all income kinds, signs, exact/sparse days, independent category/day/lifetime reconciliation, late delivery, JSON resume, legacy opening/resume, duplicate and malformed duplicate IDs, rejected ID reuse, fractional/nonfinite/incorrect types, checksum/amount/identity/time/order and total tampering, transactional rejection, exact integer overflow guards, immutable returned state, contrast, every guest's selection signal, follow/departed handling, warning/recovery, payroll/hire/dismiss intents, keyed removal, navigation, first-open layout, focus/scroll retention across twenty repeated refreshes, compact guest navigation, responsive bounds, empty-state behavior and unchanged protected saves.

The prepared W6 ledger section was run unchanged:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\PROJECTS\Resortis - 31-10-26' --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\worker-5-independent-ledger.log' --script 'res://tests/living_resort_checks.gd' -- --only=ledger --allow-pending
```

Result: **25 checks, 0 failed cases, 0 pending cases, exit 0**, report `artifacts/living-resort-checks-ledger.json`. This runs the prepared independent scenarios; it does not replace coordinator/W6 integrated review.

A native Compatibility render run of the sample fixture used the same W5 script with `-- --capture`, producing **245 checks, 0 failures** at that revision. The subsequent additions were the legacy provenance tooltip and more ledger/contrast/warning-recovery assertions; the rendered layout is unchanged. Log: `artifacts/worker-5-management-render.log`. There was a nonfatal `user://` shader-cache-folder warning; the AMD OpenGL renderer produced every expected PNG. No approval escalation or fallback art was used.

All four sample sections were visually inspected at 1440×900 and 960×600; captures were reset to their first-view scroll positions only by the capture harness after preservation assertions. Files:

- `artifacts/worker-5-guests-1440x900.png`, `worker-5-guests-960x600.png`.
- `artifacts/worker-5-facilities-1440x900.png`, `worker-5-facilities-960x600.png`.
- `artifacts/worker-5-staff-1440x900.png`, `worker-5-staff-960x600.png`.
- `artifacts/worker-5-operations-1440x900.png`, `worker-5-operations-960x600.png`.

These contain sample views on a plain backdrop, not evidence of real gameplay admissions, jobs or money. They establish readable panel presentation and fit, not world integration acceptance.

## Integration instructions and remaining boundaries

1. Current root calls (`build/refresh/show_section/close` and two-argument `action_requested`) already match this UI. Keep passing the complete wrapper `inspect(selected_person_id,following)` view. Section action strings are exactly the contract strings above; Results is the compact caption for `operations`.
2. Attach one ledger to W1; its existing event sink and cleanliness wage drain should be the only delivery path. A duplicate returns false intentionally. Do not infer a failed gameplay payment from a repeated delivery. No event is emitted by restoring the ledger.
3. Store the complete ledger capture, including journal and checksum, inside the staged live-resort envelope. Do not rebuild a journal from its displayed totals. The wrapper's existing `income_total`/simulation-income and `wages_total`/`cleanliness.total_wages` checks match these exact fields.
4. **Concrete envelope check requested:** also compare `ledger.inspect(simulation.clock).last_event_time <= simulation.clock`. A standalone `record` has no current-clock parameter and cannot reject a well-formed future event on its own. Cross-service identity/receipt ownership and payroll/payment conservation remain the envelope's responsibility. No other owner's file was edited to add this.
5. Legacy opening amounts should be seeded once by the wrapper, then preserved by ledger capture/resume. Do not replay imported room or activity income from W1. Original activity category/dates remain unknown; inspect reports the wrapper's supplied opening timestamp honestly.
6. W2 currently exposes optional `unhappy_elapsed`/`mood_reason` and uses 18s/30s warning tuning; the UI matches these current defaults. If those thresholds change, provide display-ready warning fields or update the presentation interpretation together.
7. Real in-game guest picking/follow camera, actual hire/dismiss routing and payroll, save/resume across live admissions/cleaning, real-game rendered UI/HUD coexistence, performance and full existing regressions remain for coordinator/W6. No full gate, import, bake or asset/source acceptance was performed by this worker. Construction charging, loans, upkeep and a cash balance are deliberately outside this approved batch.

No required W5 module is left as a stub. Ownership is released for coordinator integration/review after this handoff.

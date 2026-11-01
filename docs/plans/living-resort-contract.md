# Living resort worker contract

Approved scope: `2026-11-01-living-resort-plan.md`. Coordinator owns this contract; workers request changes in their handoff notes rather than silently inventing competing interfaces. Read AGENT.md first. Six worker chats total; no further subagents or chats. All share this checkout; no Git/worktrees. Only the coordinator edits shared scene wiring, top-level saves, existing tests/docs, source approval and derived asset scenes. Use isolated test saves and absolute log paths. Workers may run their own test scripts; do not run broad import/bake/approval jobs concurrently.

## Ownership

- W1: `scripts/simulation/resort_simulation.gd`, `scripts/simulation/booking_registry.gd`, `tests/population_checks.gd`, own handoff.
- W2: `scripts/simulation/guest_brain.gd`, `scripts/simulation/guest_profiles.gd`, `tests/guest_decision_checks.gd`, own handoff. Keep original GuestStay as a legacy reference/fixture; implement new decisions without changing the old class. The new controller uses per-person dictionaries so couples can separate.
- W3: `scripts/simulation/facility_sessions.gd`, `scripts/simulation/party_coordinator.gd`, `tests/facility_session_checks.gd`, own handoff.
- W4: `scripts/simulation/cleanliness_system.gd`, `scripts/world/cleanliness_view.gd`, `assets/staff/`, new staff-only authoring helpers/prompts/tests and own handoff. Existing guest art and asset library belong to coordinator. Complete new staff images must be saved in workspace; source prompts preserved. Coordinator does shared baking/imports.
- W5: `scripts/ui/resort_management_ui.gd`, `scripts/simulation/operating_ledger.gd`, `tests/management_checks.gd`, own handoff.
- W6: `tests/living_resort_checks.gd`, `tools/capture_living_resort.gd`, `docs/plans/living-resort-qa.md`, own handoff. Independent review; do not edit production code or existing tests.
- Coordinator: world/HUD integration, save schema/migration, actor/ball presentation, shared adapters, baseline and regression runs, source approval, final asset outputs/documentation. Can modify a worker's files after handoff; do not edit a file while its owner is still implementing it.

Each worker writes `docs/plans/handoffs/worker-N.md` with changed files, public API, tests/results, known gaps and concrete integration instructions, then finishes its chat. No need to send messages to another chat: coordinator reads final summaries and handoffs. No features may be declared implemented merely because data/art exists.

## Shared data

Use Godot logical `Vector2` positions; project through IsometricGrid only at rendering. Class APIs use Dictionaries/Arrays so workers do not depend on incomplete global class registrations. Validate JSON numeric integers as integral finite values, not merely `int(value)` coercions.

`ResortSimulation` (W1) is the sole owner of the live population/time and booking money. Public fields: `layout`, `assets`, `clock:float`, `people:Array[Dictionary]`, `parties:Array[Dictionary]`, `facilities:RefCounted` (nullable), `cleanliness:RefCounted` (nullable), `ledger:RefCounted` (nullable). Do not duplicate the original fourteen ambient walkers in new runtime.

Person dictionary required fields: `id:int`, `party_id:int`, `role:int` (0/1 for bed position), `profile:Dictionary`, `motion:GuestMotion`, `state:String`, `needs:Dictionary` with hunger/rest/enjoyment, `mood:float`, `warning_elapsed:float`, `want_leave:bool`, `reason:String`, `history:Array`, `activity:String`, `facility_id:int`, `slot:int`, `activity_elapsed:float`, `timer:float`, `session_paid:bool`. Optional internal fields are permitted but must serialize. `motion` owns actual position, heading, distance, moving and routes; do not maintain a conflicting second position. Profile required fields: `name`, `variant` female/male, `interests:Array[String]`, `initial_needs:Dictionary`.

Person states: `arriving`, `waiting_room`, `to_cabin`, `entering`, `sleeping`, `exiting`, `deciding`, `to_facility`, `queueing`, `approaching_activity`, `sitting`, `eating`, `lying`, `volleyball`, `leaving_activity`, `strolling`, `waiting_partner`, `returning`, `departing`, `departed`. Add internal states only if documented in handoff. Activities: `meal`, `sunbathe`, `volleyball`, `rest`, `stroll`. Map to existing art poses `sitting/eating/lying/volleyball/sleeping` in controller `activity_slot(person_id)`.

Party dictionary required fields: `id`, `member_ids:Array`, `nights` 1–3, `initial_budget`, `budget`, `cabin_id`, `paid_nights`, `room_spent`, `activity_spent`, `created_at`, `next_night`, `state`, `history`. Shared room charges once per party/night; activity charges per admitted person. Protect unpaid room reserve. Reunite members before overnight deadline and checkout; prevent one partner leaving a reservation behind. Use the existing cabin aisle and exact fixture slots, including distinct role 0/1 positions.

One shared fixed-step simulation clock. DAY_SECONDS=180. Arrivals use a persisted RNG, stable monotonic IDs, cap 12 people (room availability may lower real occupancy). Keep departed records bounded. For the first party use Maya/Leo, two nights and $480 shared budget for continuity; subsequent profiles/lengths/budgets vary. At least some arrivals should be couples, and no cabin is assigned to two active parties. Seed/cap parameters may be optional configure arguments.

## W1 public controller API

- `configure(map: ResortLayout, library: ResortAssets, seed_value:int=8147) -> void` initializes a fresh population, with first party ready for the initial advance; no user save I/O.
- `advance(delta:float) -> void` bounded fixed steps; advances needs, routes, room lifecycle and attached facilities/cleanliness/ledger services in stable order. Do not advance the same service twice in world wiring.
- `person(id:int)->Dictionary`, `party(id:int)->Dictionary`, `activity_slot(person_id:int)->Dictionary` (existing actor slot contract or empty), `inspect()->Dictionary` (UI contract below).
- `protects(object_id:int)->bool`, `access_survives(candidate:ResortLayout)->bool`, `layout_changed()->void` cover ALL active guests and service reservations. Keep occupied-object/path protections.
- `capture()->Dictionary`, `restore(data:Dictionary)->bool`: JSON-safe simulation-only snapshot, validated transactionally before assigning state. It must preserve profiles, money, deadlines, RNG state, IDs, all routes/elapsed activity and reservations. No write to player files. Coordinator wraps service snapshots in the new layout schema.
- `import_legacy(data:Dictionary)->bool`: validate via legacy GuestStay.restore, import one solo/couple booking preserving money, cabin, positions, route distance, paid nights, deadline and current activity. Publish exact mapping/remaining reconstruction needs in handoff. Coordinator will verify and finalize migration; do not reset legacy money/booking or rewrite the original save.
- `drain_events()->Array[Dictionary]` if no ledger attached; if ledger attached, record each financial event with its unique ID directly. No duplicate event on resume. A finished facility visit notifies attached cleanliness service.

W1 may read new modules with preloads after they exist; avoid requiring missing W3/W4/W5 files at parse time. Access nullable services through methods. Persist any undelivered events. Newborn or queued people need distinct visible waiting positions, not every actor at ARRIVAL.

## W2 decision/profile API

`GuestProfiles.create_party(rng:RandomNumberGenerator, party_id:int, size:int=0)->Dictionary`: return `{nights:int,budget:int,members:Array[Dictionary]}` with 1/2 profiles. Choose size when 0. Use caller RNG exclusively. Profiles/initial budgets/interests must be plausible and deterministic. At most two members supported in this batch.

`GuestBrain.advance(person:Dictionary, delta:float, cleanliness_score:float=100.0)->void`: updates individual needs/mood/warning and want_leave. Need recovery follows actual eating/sleeping/lying/volleyball states, not a decision made while walking. Separate dirt/mood from hunger. Warning and recovery before early departure. Do not own money, navigation or rooms.

`GuestBrain.choose(person:Dictionary, party:Dictionary, available:Array[Dictionary], clock:float)->Dictionary`: `{activity:String,facility_id:int,reason:String}`. Available entries: `{kind:String,id:int,price:int,distance:float,available:bool,queue:int}` where kind is cafe/sunbeds/volleyball. Pick meaningful alternatives, guard reserves, respect interests and avoid task thrashing. Rest/stroll return facility_id -1. Current task completion/cooldown belongs to controller.

## W3 facilities/party API

`FacilitySessions.configure(map,library)->void`; `request(person_id:int,party_id:int,facility_id:int,activity:String,clock:float,preferred_partner_id:int=0)->Dictionary`; `ticket(person_id:int)->Dictionary`; `confirm_arrival(person_id:int,clock:float)->bool`; `ready(person_id:int)->bool`; `release(person_id:int)->void`; `advance(delta:float,clock:float,people:Array=[])->void`; `slot(person_id:int)->Dictionary`; `route(person_id:int,leaving:bool=false)->Array[Vector2]`; `inspect()->Array`; `capture()->Dictionary`; `restore(data:Dictionary)->bool`.

Tickets include `status` queued/reserved/active/expired, person_id, party_id, facility_id, activity, slot index, `queue_position:Vector2`, `partner_id`, admitted/arrival flags and timestamps. Two physical café seats, two loungers per asset, two opposite court positions. Charge in controller only after arriving at a slot and ready(), once via session_paid. First volleyball arrival waits for the second; bounded waits release both safely. FIFO waiting slots must be unique, reachable and off protected entrances. Slot/route derive from GuestActivitySlots; no new source-space guesses for furniture. Queue lanes may have logical ground positions validated against navigation.

`PartyCoordinator.should_join(person:Dictionary,partner:Dictionary,intent:Dictionary)->bool` suggests shared leisure when both are free/compatible; urgent individual needs win. W1 applies companion intent only at safe decision states and handles overnight/checkout reunion. W3 may add documented helpers; keep all navigation/money in W1. No endless partner wait.

## W4 cleanliness/staff API

`CleanlinessSystem.configure(map,library)->void`; `advance(delta:float,clock:float)->void`; `on_activity_finished(person_id:int,facility_id:int,activity:String,clock:float)->void`; `score_at(position:Vector2)->float` 0–100; `hire()->Dictionary` result with ok/reason/id; `dismiss(staff_id:int)->bool`; `inspect()->Dictionary` with mess, staff, cleanliness, hired_count; `layout_changed()->void`; `access_survives(candidate)->bool`; `capture()->Dictionary`; `restore(data:Dictionary)->bool`; `drain_events()->Array[Dictionary]` for wages.

Mess/staff inspect records use logical positions. Staff has id, state (walking/cleaning/idle), motion (GuestMotion internally), target_mess_id, activity_elapsed. Persist RNG/jobs/claims/wage day. Wage default $30 per hired staff per completed 180-second day; no upfront hire cost, max 3. Produce uniquely identified negative wage events once per day/staff. Safe dismissal releases claims. Actual reachable cleaning, bounded mess, event-driven generation. The coordinator will attach wage events to ledger; W1 should drain these after each advance if ledger attached.

`CleanlinessView` is a Node2D attached to the world, configured with system/library; update via `refresh()` (or document exact equivalent). It renders mess and real staff at correct depth and motion. Coordinator handles connection/imports. Do not warp guest walking artwork. New staff-only masters/bake helpers may be created by W4 but shared bakes/approval run only by coordinator.

## W5 ledger/UI API

`OperatingLedger.record(event:Dictionary)->bool` idempotent; `inspect(clock:float)->Dictionary`; `capture()->Dictionary`; `restore(data:Dictionary)->bool`. Events `{id:String,kind:String,amount:int,time:float,party_id:int,person_id:int,staff_id:int}` optional identity fields. Kinds room/meal/sunbathe/volleyball/wage plus `legacy_income` for imported aggregate activity income whose categories were not saved previously. Amount is signed. Inspect exposes `income_total`, `wages_total` (positive expense), `net_total`, `today_income`, `today_wages`, `today_net`, `day` and `days:Array`; extra fields are allowed. Income totals, wages and net operating result by day; no new construction economy. The wrapper seeds legacy opening room/activity totals once; W1 must not replay them. Keep a JSON-safe event journal in capture for audit/validation. Coordinator cross-checks lifetime income against simulation totals and wage totals against cleanliness payroll state.

`ResortManagementUI extends CanvasLayer`: signals `action_requested(action:String,id:int)`; `build()->void` if needed; `refresh(view:Dictionary)->void`; `show_section(section:String)->void` (guests/facilities/staff/operations); `close()->void`. Expose guest selection/follow and staff hire/dismiss actions. Keep panels between existing top HUD and building tray, scroll rather than cover controls. Matching current calm green/cream UI. No gameplay state stored in widgets.

Root `view` keys: clock, people:Array, parties:Array, facilities:Array, cleanliness:Dictionary, operations:Dictionary, selected_person_id:int, following:bool. People flattened inspect records include id, party_id, name, variant, state, position:Vector2, needs, mood, warning_elapsed, reason, interests, budget, reserve, cabin_id, nights, paid_nights, history, partner_id. Staff cleanliness records should similarly be display-ready, not raw object references.

UI actions: select_guest/follow_guest with person id; hire_janitor id 0; dismiss_janitor with staff id; close id 0. Coordinator adds Guests/Facilities/Staff/Operations entry controls to existing HUD. Worker UI must be testable with sample view dictionaries without world edits.

## Save integration and QA

Coordinator adds a new optional live-resort snapshot to a new layout schema, retaining old layout and guest_stay readers. New snapshot envelope: `{version:1,simulation:...,facilities:...,cleanliness:...,ledger:...}`. Assemble/validate candidates before replacing current state. Cross-validate identities, bookings, ticket ownership, exact money/event totals and job claims. Keep original guest_stay as legacy compatibility data where needed; live simulation is authoritative. Do not have two active overlapping simulations.

W6 first produces acceptance checklist and tests for the above agreed APIs, then hands off and waits until resumed for integrated QA. Tests may initially fail because features are pending; report that honestly. Final QA includes 1–3 nights, different choices, queues, shared/leisure split, reuniting, dirt/warning/recovery/cleaning, wages and money conservation, mid-action save/resume, invalid snapshots, path editing and actual render evidence. Use `tests/living_resort_checks.gd` plus a real capture helper. Coordinator will wire them into the complete gate after implementation.

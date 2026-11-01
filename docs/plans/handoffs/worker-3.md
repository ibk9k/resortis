# Worker 3 handoff: facilities and companion coordination

Status: owned implementation and focused checks complete. The coordinator still owns controller/world integration, independent acceptance, full regression runs and visual approval. Only the three owned implementation/test files and this handoff were authored. No other worker's file, player save, accepted guest artwork/walking, shared scene, import, bake or source approval was changed.

## Delivered files

- `scripts/simulation/facility_sessions.gd`: `class_name FacilitySessions`, `extends RefCounted`.
- `scripts/simulation/party_coordinator.gd`: `class_name PartyCoordinator`, `extends RefCounted`.
- `tests/facility_session_checks.gd`: memory-only service and companion scenarios; no world startup or save writes.
- `docs/plans/handoffs/worker-3.md`: this handoff.

The two new scripts load directly without an editor import in the focused checks. Normal shared registration/import remains the coordinator's job.

## FacilitySessions API and behavior

All contract methods are implemented: `configure(map,library)`, `request(person_id,party_id,facility_id,activity,clock,preferred_partner_id=0)`, `ticket(person_id)`, `confirm_arrival(person_id,clock)`, `ready(person_id)`, `release(person_id)`, `advance(delta,clock,people=[])`, `slot(person_id)`, `route(person_id,leaving=false)`, `inspect()`, `capture()`, `restore(data)`.

Optional controller protection hooks are also implemented: `protects(object_id)`, `access_survives(candidate)`, `layout_changed()`.

- Every café, sunbed unit and volleyball court has **two physical claims**. A matching activity is required: meal/cafe, sunbathe/sunbeds, volleyball/volleyball.
- Each facility has a queue of at most **four**. Successful requests have one globally monotonic sequence, and promotions follow persisted insertion order. A new request cannot take an older waiting person's vacancy. Duplicate matching requests return the same ticket; conflicting requests for an already committed person fail with `{}`.
- `request()` fails with `{}` for invalid IDs/clocks, a mismatched or unreachable facility, a full queue, or insufficient safe waiting ground. It never moves a person, pays a fee or admits a customer.
- `slot()` and `route()` use **GuestActivitySlots**, with the existing eating/lying/volleyball fixture poses and the actual claim index 0/1. Queued visitors have no fixture or approach route. Exit routes reverse the exact accepted approach. An expired ticket retaining an exit claim can still supply its fixture/route.
- Both identities can occupy either role; a facility claim index is independent of party role. In particular, two solo role-0 guests can occupy opposite volleyball positions.
- A queue station is an integer logical navigation point, at least 1.05 tiles from every facility/cabin entrance and the arrival anchor. No fractional offsets were needed. Queue stations are unique **across facilities**, not just within one facility.
- Each ticket retains its station through its visit. This conservatively prevents reuse under a just-promoted walker. Visible queued people use only their own queued ticket's station; unused admitted-ticket stations are access reservations, not additional visible people.
- Placement checks stage **all** station cells as obstacles at once. Every entrance remains reachable, and every station has an accessible neighbouring cell. Thus individually reachable stations cannot collectively seal a narrow path. The full starter fixture successfully held 42 tickets across seven facilities while preserving all entrances.
- `access_survives()` preserves occupied/queued facility identity, kind, position and orientation, every station and combined circulation. It rejects covering a waiting station. These are additional protections; W1 remains responsible for each person's full current route.

### Admission, volleyball and exits

- `confirm_arrival()` is an assertion by the caller that its person reached the exact fixture. When `advance(..., people)` supplies live person dictionaries, confirmation additionally verifies their **same GuestMotion object** is within 0.12 logical tiles of the assigned fixture, with matching facility/activity. There is no copied position state. Standalone service tests can assert arrival without binding a population.
- Meals and loungers become active on actual fixture arrival. Volleyball requires **both** reserved players to arrive. Both tickets then get the same `active_at` and `match_id`, with reciprocal actual `partner_id` values. Repeated confirmations cannot replay admission or reset timestamps.
- A companion hint is stored in `preferred_partner_id`; it is advisory. It never creates an absent partner claim or permits queue jumping. The two FIFO-selected positions pair companions or people from different parties equally.
- `ready()` means currently active, physically arrived, admitted, and claim held. A volleyball ready result additionally requires the corresponding ready peer and reciprocal match ownership. It is the gate for a controller charge; it is **not** a record that a payment happened.
- `release()` means the controller has completed that person's physical exit. It removes that ticket and promotes waiting people immediately. Releasing a matched player expires the peer's ticket too, preventing an orphan rally.
- With a live `people` list, an active volleyball player's `leaving_activity`, `returning` or `departing` state expires both tickets on the next shared service step, before the first exit route finishes. W1's expired-ticket handling can then walk the other player out rather than continuing a solo rally.
- Expiry stops readiness immediately. A physically present/arrived person keeps `claim_held=true` while walking out. Neither that court position nor its station can be assigned underneath them. `advance()` frees an expired claim once the actual person clears the facility; `release()` explicitly finishes it. Missing/departed people also cannot retain live claims.
- Passing a nonempty `people` array binds an authoritative population for that step. The service-only empty-list mode has no real actors to observe and releases expired evacuation claims after a 30-second cleanup allowance. Production should always pass the actual W1 population each step.

Tuning, in shared simulation seconds:

| Limit | Value | Origin |
| --- | ---: | --- |
| Physical capacity | 2 | Per asset, all three kinds |
| Visible queue | 4 | Per asset |
| Total queue wait | 55 | From request, not reset by walking |
| Unarrived reservation | 90 | From promotion/reservation |
| Arrived lone-player wait | 22 | From physical first arrival |
| Stale active session | 60 | From actual admission; normal controller activities finish sooner |
| Unbound exit cleanup | 30 | Only without an observed live population |
| Queue search | 18 | Maximum navigation steps from facility entrance |
| Free expired notifications retained | 64 | Oldest discarded first |

Timeouts are processed chronologically against the supplied shared clock. One long elapsed-time advance has the same expiry/promotion result as small steps. The service never advances a private simulation clock independently or accesses a save file.

## Inspect fields

`inspect()` returns one dictionary per actual cafe/sunbeds/volleyball asset:

| Field | Meaning/type |
| --- | --- |
| `id`, `facility_id` | Same placed-object ID |
| `name`, `kind`, `activity`, `price` | Display metadata; existing $12/$8/$10 defaults |
| `capacity` | Always 2 |
| `occupants:Array[int]` | All people holding physical claims: reserved, active or still exiting |
| `occupancy:int` | Number of held physical claims |
| `active:Array[int]` | Currently admitted active tickets |
| `reserved:Array[int]` | Reserved visitors still approaching/waiting for a player |
| `exiting:Array[int]` | Expired tickets still holding their physical exit claim |
| `queue:Array[int]`, `queue_count:int`, `queue_limit:int` | FIFO waiting identities, count, limit 4 |
| `waiting_positions:Array[Vector2]` | Visible queued anchors, parallel to `queue` |
| `reachable:bool` | Entrance reaches arrival through actual navigation |
| `available:bool` | Can accept a request into a physical place **or bounded reachable queue** |
| `immediate_vacancy:int` | Currently unclaimed physical places, 0–2 |
| `available_now:bool` | A place is immediately free and no older queued person precedes the request |
| `session_started_at:float` | Active start time; volleyball players share it |

Do not gate the decision offer on `immediate_vacancy`: a full physical facility with a free queue position is intentionally available. `occupants` and `queue` remain ID arrays as the existing W1/UI adapter expects.

## Snapshot contract

`capture()` returns JSON-safe `{version:1,clock:float,next_sequence:int,tickets:Array[Dictionary]}`. Ticket array order is the authoritative FIFO order and sequences must be strictly increasing. Each ticket has exactly these fields:

```
person_id, party_id, facility_id, activity, status, slot, queue_position,
partner_id, preferred_partner_id, sequence,
arrived, admitted, claim_held,
requested_at, reserved_at, arrived_at, active_at, expired_at,
match_id, reason
```

Runtime `queue_position` is Vector2; capture encodes `[x,y]`. Runtime IDs, index and sequence are integers; JSON integral finite floats are accepted and normalized. Fractional/nonfinite integers, including almost-integral queue coordinates, are rejected before Vector2 rounding.

`status` is queued/reserved/active/expired. Queued slots are -1 and have no arrival/admission. Expired notifications may retain their old slot and historical arrival/admission flags. **Only `claim_held` determines physical occupancy**, and `ready()` always rejects expired tickets. Free expired notifications may reference a subsequently removed facility or reused station; held or live tickets require a current matching reachable asset and valid exclusive station.

`restore()` validates into candidates and replaces state only after all checks pass: duplicate people/slots/stations, FIFO sequence/order, queue bounds/vacancies, flags/status, monotonic finite timestamps/deadlines, actual facility kind/navigation, paired court ownership/start times, and combined queue circulation. Restoring a snapshot never calls promotion, arrival or admission. No fee or activity event is emitted. An arrived lone player remains waiting with its original deadline; an active match keeps its shared start; a cancelled pair keeps both evacuation claims.

The top-level envelope must still cross-validate each ticket's person/party/facility/activity against W1, validate the service clock against the simulation clock, and keep W1's `session_paid`/receipts/ledger consistent. Facility admission owns no money and cannot substitute for those checks. Cross-validation must permit an expired ticket with a held exit claim while its person is approaching/leaving the facility.

## PartyCoordinator

`static should_join(person:Dictionary,partner:Dictionary,intent:Dictionary)->bool` is pure and creates no new person fields or wait state.

- Requires distinct positive identities in the same party; the joining person must be `deciding`.
- The invited person may be deciding, approaching a facility, queued, approaching their activity or waiting for their player. A committed invitation must match that person's actual activity/facility.
- Shared suggestions cover sunbathing, volleyball and strolling. Both the current symbolic interests and W2's display interests (`Sunbathing`, `Volleyball`, `Beach walks`) work.
- Hunger <=30 or rest <=25, `want_leave` or `return_requested` in either person always wins over leisure. The joining person also keeps a small safety margin (hunger >40, rest >35). Volleyball requires both people at rest >=50 and the joining person's volleyball interest. Sunbathing permits its explicit interest or a compatible quieter recovery need. Differing interests can produce independent activities.
- This never cancels a current task, reserves a facility or forces either member to wait. The service's 22-second player timeout bounds physical waiting. W1 remains responsible for reunion at night and checkout, budgets and safe decision timing.

## Integration instructions and remaining coordinator work

1. Attach/configure the service before advancing a fresh W1 simulation. Advance it **once** per shared step, with the real person dictionary array, before individual routes/decisions. The existing W1 external-service hook already does this. Do not also advance it from the world.
2. Route outdoors to the ticket station/entrance, then follow `route()` to the fixture. Charge only after actual arrival and `ready()`, guarded by the persisted per-person `session_paid`. Prices are unchanged. For volleyball, inspect the **actual ticket partner**, possibly in another party, and validate/charge both players atomically before either enters the rally pose. The latest W1 code inspected already includes `_start_volleyball()` with this atomic spending path; it still needs integrated acceptance against this service.
3. Keep the ticket through physical exit, then call `release()`. Honor an expired ticket for every committed activity state so the peer cancellation signal triggers a safe exit. Never use `admitted` as an instruction to charge again after restore.
4. **Concrete W1 follow-up requested:** `_available()` currently uses only `queue_count < 4`. Also honor this service's `available` field so an edited map with fewer safe station cells is not repeatedly offered. Preserve occupied facilities' queue admission; do not replace this with an empty-seat check.
5. **Concrete W1 follow-up requested:** `_leave_activity()` currently reverses the complete approach even if a person is cancelled halfway through it. Build an exit from the person's current position through only the already traversed portion (or otherwise guarantee a safe retreat). Reversing the whole list first sends a half-arrived person toward the final fixture, potentially into a newly assigned place or across a corner. Keep each evacuation claim until the actual route clears. This worker did not edit the controller.
6. **Concrete W1 follow-up requested:** a queued ticket can be promoted while its person is still `to_facility` and walking to the old queue station. `_arrived()` currently sees the new reserved status and immediately calls `_approach_activity()`, whose first point is the doorway. First route from that station to the actual doorway through outdoor navigation, then follow the fixture approach. Otherwise that first segment can cut straight across scenery/another facility. The already-queueing promotion path in `_advance_queue()` does perform the outdoor doorway route; give the in-transit promotion case the same protection.
7. **Concrete W1 follow-up requested:** the arrival/room waiting-point allocator currently considers only its own arriving people. Avoid any existing facility queue station when selecting a newborn/room-waiting anchor, particularly near the arrival promenade. Facility stations are mutually exclusive already; this prevents a different population wait from spawning on one. `capture().tickets` exposes every live/held station; `inspect().waiting_positions` exposes the currently visible queued stations.
8. Use fixture claim index, not party role, for activity presentation and court facings. The accepted post-avoiding approach crosses x=3.5 only beyond y=4.45 relative to the court; focused tests verify both paths against the current model's posts. No art/route helper was modified.
9. Wrap these snapshots in the coordinator's transactional envelope, including the held-expired-claim case above. Legacy reconstruction, full cross-service validation, promotion during travel, partial-approach cancellation, room-night/checkout reunion, fee/ledger idempotency and UI/world saves still require integrated checks. This is a service handoff, not final game acceptance.

## Validation

Project-local Godot 4.7.2, no import/full gate:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\PROJECTS\Resortis - 31-10-26' --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\facility-session-checks.log' --script 'res://tests/facility_session_checks.gd'
```

**`FACILITY_SESSION_CHECKS 951 checks; 0 failures`, exit 0.** All three capacities/FIFO queues, no premature readiness, duplicate request idempotency, physical arrival checks with real GuestMotion, stable queue geometry across every starter facility, combined entrance circulation, protection against station/facility edits, cancellation while physically exiting, both same-party and cross-party volleyball, opposite fixtures/facings/post clearance, shared starts, lone-player deadlines, active/queued/waiting/expired-held JSON resume, malformed/duplicate/near-duplicate/backward-time snapshot rejection with transactional preservation, coarse/fine timeout equivalence, unavailable maps, and safe/urgent/split companion suggestions pass.

The prepared independent facility section was also run unchanged:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\PROJECTS\Resortis - 31-10-26' --log-file 'E:\PROJECTS\Resortis - 31-10-26\artifacts\facility-independent-checks.log' --script 'res://tests/living_resort_checks.gd' -- --only=facilities
```

**103 checks; 0 failed cases; 0 pending cases, exit 0.** Report: `artifacts/living-resort-checks-facilities.json`. The report verifies all protected workspace/direct-play saves and backups are byte-for-byte unchanged. This executes W6's prepared scenarios; it does not replace W6's later independent integrated review.

No actual rendered queue/court/couple motion review, game-wide performance measurement, full legacy/asset gate, baking or source approval was performed. Those remain with the coordinator as instructed. The checks establish service behavior and geometric reachability, not final visual approval or complete controller gameplay.

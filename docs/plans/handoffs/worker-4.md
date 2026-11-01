# Worker 4 handoff — cleanliness and janitors

Status: owned implementation complete and focused checks pass. Shared staff bake/import, integration render/occlusion review and source approval remain with the coordinator. No shared production file, accepted guest source/walking output, player save or backup was edited by this worker. No import, shared bake, full gate or source approval was run.

## Files

- `scripts/simulation/cleanliness_system.gd`: service, exclusive job claims, navigation/cleaning, payroll, validation and JSON snapshot.
- `scripts/world/cleanliness_view.gd`: mess marks and janitor actor roots under world Y sorting; presentation only.
- `assets/staff/masters/janitor-walk-v1.png`, `assets/staff/masters/janitor-clean-v1.png`: original transparent built-in ImageGen outputs, copied into the workspace. Exact prompts: `assets/staff/prompts/janitor-walk-v1.txt`, `assets/staff/prompts/janitor-clean-v1.txt`.
- `assets/staff/janitor_art.gd`, `assets/staff/janitor_skin.gd`, `assets/staff/README.md`: staff-only registration, pose source, guarded frame loader and commands.
- `tools/bake_staff.gd`: coordinator's staff-only bake, or artifact-only GPU preview.
- `tests/cleanliness_checks.gd`, `tests/cleanliness_view_checks.gd`, `tests/staff_art_checks.gd`.
- This handoff. Engine-generated `.uid` files beside new scripts are expected derived registrations.

## Public seam and tuning

`CleanlinessSystem` implements every contracted method: `configure(map,library)`, `advance(delta,clock)`, `on_activity_finished(person_id,facility_id,activity,clock)`, `score_at(position)`, `hire()`, `dismiss(staff_id)`, `inspect()`, `layout_changed()`, `access_survives(candidate)`, `capture()`, `restore(data)`, `drain_events()`.

`CleanlinessView.configure(system,library)` then `refresh()` is the world integration seam. Attach it under the same Y-sorted world as the population view. It creates janitors and dirt only. It reads display records; it never calls `advance()`. Leave time advancement and wage draining in W1. Its sprite pose follows actual distance for walking and persisted `activity_elapsed` for sweeping.

- No automatic hire or upfront cost; max three active hires. A hire stands on a distinct reachable arrival-path cell. Monotonic IDs are retained after dismissals.
- Completed meals / sunbathing / volleyball visits generate dirt with probabilities 0.65 / 0.35 / 0.40. Meals have a 40% chance of a spill when dirt is generated. Other dirt is litter. No rendered-frame/idle timer spawns.
- Max 32 mess records; max 8 from one facility. Candidate ground is reachable within 3.5 tiles of the real facility entrance, excluding protected entrances and occupied dirt cells. Repeated completion receipts are bounded to the most recent 128 callbacks.
- `score_at` is strictly local: radius 4.5 tiles, linearly attenuated penalties 19 litter / 24 spill, clamped 0–100. `inspect().cleanliness` is the average score at current dirty locations (100 when none), so it describes dirty-area condition rather than a whole-map area-weighted average.
- Staff use real `GuestMotion` at the existing 1.2 tiles/sec, including its 0.6-second route delay. They choose the shortest reachable unclaimed job. One claim per job; stop at most 0.4 tiles before the mess, face it, and clean for 4.5 seconds (litter) / 6 seconds (spill). Work cannot remove distant dirt. They then claim another job or idle.
- State machine is exactly `idle`, `walking`, `cleaning`; no extra staff states. Dismissal releases the claim. Safe path detours preserve position, walked distance and the job, then replan. Removing an occupied edge endpoint or disconnecting any staff/job is refused by `access_survives`.
- Service work uses a carried 1/30-second remainder. Normal W1 calls use its shared step; long standalone calls up to 1200 seconds are bounded to 36,000 service steps. Nonfinite/negative/reversed/zero-time movement input does not progress work.
- **Payroll:** $30 per currently hired staff at each exact completed global 180-second day, including late-day hires. A hire exactly on a boundary first owes the next day. Events are `{id:"staff:wage:<staff_id>:<day>",kind:"wage",amount:-30,time:<day*180>,staff_id:<id>}`. No repeat charge on paused/same-day updates or after resume. Dismissed staff do not accrue later wages.
- **Requested integrity addition:** public positive expense `total_wages:int`, also `capture().total_wages` and `inspect().total_wages`, is lifetime payroll including dismissed staff. It increases at event creation and is unchanged by draining. Reconcile it against ledger lifetime wages after the controller's same-advance flush; pending cleanliness events also persist before delivery.

Inspect staff fields: `id,name,role,state,position:Vector2,direction:Vector2,distance,moving,target_mess_id,activity_elapsed,progress,cleaned_count,wage,daily_wage,reason`. Mess fields: `id,kind,position:Vector2,facility_id,created_at,claimed_by,style`. Root view additionally has `hired_count,max_staff,daily_wage,mess_count,cleanliness,clock,total_wages`.

## Save and integration details

Snapshot version 1 contains `clock,pending_time,wage_day,next_mess_id,next_staff_id,total_wages,rng_seed,rng_state,mess,staff,pending_events,recent_visits`. RNG seed/state are canonical signed-64-bit decimal strings, preserving JSON precision and rejecting overflow before conversion. Positions/routes encode as numeric arrays; staff motion additionally retains `moving`. Claims are cross-validated bidirectionally. Elapsed cleaning, directions, root positions, route delay/index/distance, future RNG and undelivered wages resume exactly.

`restore()` stages a temporary candidate and rejects malformed IDs, numeric booleans/fractions, broken state/claim pairs, blocked/disconnected roots, diagonal/oversized route segments, impossible cleanup reach/progress, future dirt, malformed payroll and duplicate pending wages without changing the live service. Retained staff's completed wage minimum cannot exceed `total_wages`. Historical source facility IDs may remain on dirt after a facility moves/removes; the actual dirt ground must still be reachable.

**Coordinator action for legacy import:** after importing a guest-only legacy snapshot into a fresh no-staff cleanliness service, call `cleanliness.advance(0.0,simulation.clock)` before exposing hiring or capturing the new envelope. This synchronizes the existing global day without creating work or wages. A normal envelope restore already restores the service clock. This avoids interpreting a newly hired janitor as having worked days before the legacy import.

The expected controller order already matches W1: advance cleanliness once per simulation tick, finish guests and call `on_activity_finished`, drain wages into the attached ledger before returning. Completion timestamps must match the current service clock (or at most one shared step ahead). W1's `visit_notified` controls the main completion idempotency; the service also protects its most recent duplicate callbacks.

`LivingResortRuntime.layout_changed()` currently calls simulation then cleanliness, while W1 also forwards cleanliness refresh. The second call is functionally safe; coordinator may remove that duplicate work in the shared wrapper. No worker-owned interface change is required.

## Art and exact commands

The generated staff matches the approved illustrated proportions/style but has a distinct work cap, green bib uniform, closed shoes, cloth and broom. Five authored views plus mirrors yield eight facings. Walking uses 40 complete drawings against the protected native gait guide, held as 8 keys over 16 distance slots. Sweeping uses 20 complete planted-foot paintings; centered sweep is idle with a stationary broom. No cutout limbs or warped neutral pose.

The staff-only bake is **pending coordinator execution**. It produces 168 isolated guarded frames (128 walk + 8 idle + 32 cleaning) in `assets/staff/illustrated/` and `assets/staff/registration.json`. Art uses 256×256 canvases, shoe root `(128,220)`, 200px registered body and uniform scale `49/200`. Source extraction keeps the connected full body/tool and two-pixel antialias guard, excluding neighboring broom-tip fragments. The frame loader builds mipmaps for clean normal-size sampling. Missing/stale registration or frames fail clearly rather than displaying guest art.

From the project root, using the project-local engine:

```powershell
$enginePath = Join-Path (Get-Location) '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $enginePath --path . --script tools/bake_staff.gd --log-file (Join-Path (Get-Location) 'artifacts/staff-bake.log') -- --bake
& $enginePath --headless --editor --path . --import --log-file (Join-Path (Get-Location) 'artifacts/staff-import.log')
& $enginePath --headless --path . --script tests/staff_art_checks.gd --log-file (Join-Path (Get-Location) 'artifacts/staff-art-baked-checks.log') -- --baked
```

Add the new staff masters/helpers/outputs to shared source approval and manifest as appropriate after integrated review. Existing guest art/library was not changed. `CleanlinessView` has its own staff-only loader and does not need staff inserted into `ResortAssets.people_frames()`.

Measured art regions and exact hashes are already available in `artifacts/worker-4-staff-preview/source-regions.json`. The coordinator bake remeasures them deterministically; no assumed equal-cell cropping is used. Art source prompts and originals remain intact.

## Actual checks and evidence

All commands used absolute logs under `artifacts/`, without `--workspace-data`, without default scene startup or player-file writes:

| Check | Actual result | Log/evidence |
| --- | --- | --- |
| `tests/cleanliness_checks.gd` | **3275 checks, 0 failures**, exit 0 | `artifacts/worker-4-cleanliness-checks.log` |
| `tests/cleanliness_view_checks.gd` | **25 checks, 0 failures**, exit 0; inert frame fixtures test presentation only | `artifacts/worker-4-cleanliness-view-checks.log` |
| `tests/staff_art_checks.gd` | **203 source checks, 0 failures**, exit 0 | `artifacts/worker-4-staff-art-checks.log` |
| Independent W6 suite `tests/living_resort_checks.gd -- --only=cleanliness` | **662 checks, 0 failed/pending cases**, exit 0; protected player save hashes unchanged | `artifacts/worker-4-independent-cleanliness.log`, `artifacts/living-resort-checks-cleanliness.json` |
| `tools/bake_staff.gd -- --preview-only` | Real Compatibility/AMD GPU render, exit 0; 16 frames, 8 directions, 49px and 147px | `artifacts/worker-4-staff-preview/`, `artifacts/worker-4-staff-preview.log` |

Focused behavior covers event-driven/local/reachable/bounded mess; repeated notifications; exclusive claims; physically reached cleanup; all jobs eventually cleared; dismissal/replacement; exact boundary wages; late/boundary hires; lifetime total after dismissal; undelivered events; equivalent elapsed time; mid-walk and mid-clean JSON resume; malformed restore preservation; occupied-edge protection; and a real alternate path edit with root/distance/claim preservation.

The presentation checks prove refresh is read-only, staff roots use `IsometricGrid`, poses freeze during pause, model restore/reconfigure does not duplicate actors, reached work selects cleaning, dismissal frees the staff node and completed cleanup removes ground marks. **They use inert SpriteFrames to avoid running the pending shared art bake/import; they do not claim baked-art acceptance.**

GPU review artifact: `artifacts/worker-4-janitor-motion.png` is an APNG of the real source renders. Inspected source sheets and rendered frames 00/06/10 show complete opposite steps and connected bodies, planted sweeping feet, stable head/body scale, clear green staff uniform and broom at normal and enlarged sizes in all eight facings. `--preview-only` writes artifacts only. Rebuild the APNG if rerendering:

```powershell
& $enginePath --path . --script tools/bake_staff.gd --log-file (Join-Path (Get-Location) 'artifacts/worker-4-staff-preview.log') -- --preview-only
node tools/pack-walk-preview.mjs artifacts/worker-4-staff-preview artifacts/worker-4-janitor-motion.png 75
```

The preview log contains a nonfatal inability to create the ordinary `user://` shader-cache folder in this restricted worker; the renderer still produced the inspected PNG sequence and exited 0. No engine-user permission escalation was needed for these artifacts.

## Remaining coordinator acceptance

Run staff bake/import and the `--baked` staff checks; review the actual `CleanlinessView` in the integrated world at real walking cadence, all facings, near furniture and within the shared sorting traversal. Source review is deliberately slower than real walking. Bounded four-key sweeps are complete paintings, not continuous arm interpolation. The uniform is one type reused across hires. Work zones, maintenance staff and wear remain outside this approved scope.

No shared gate or existing guest animation/occlusion regression is claimed by this worker. Coordinator owns those runs, top-level clock/ledger/job envelope cross-validation, source approval and final acceptance.

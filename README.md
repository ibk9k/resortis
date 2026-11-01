# Resortis

A Windows Godot 4.7.2 project for the agreed isometric beach resort game. The current slice is an **editable living resort with concurrent guest bookings, shared facilities and hired janitors**.

Public source repository: [ibk9k/resortis](https://github.com/ibk9k/resortis).

For a fresh development chat, start with [AGENT.md](AGENT.md). [AGENTS.md](AGENTS.md) is the automatic entry point to the same project rules and context.

## Open it

- Double-click **Play Resortis.cmd** to explore and edit the map.
- Double-click **Open Godot Editor.cmd** to inspect the project in Godot.
- Alternatively, import **project.godot** in Godot 4.7.2 Standard and press **F5**.

Install **Godot 4.7.2 Standard** separately; the engine and export templates are not included in the repository. Import `project.godot`, let the initial asset import finish, then press F5. No paid dependencies are required.

The Windows shortcuts use an optional portable installation in `.tools/godot`. Alternatively, run `tools/launch.ps1 -Engine 'C:\path\to\Godot.exe'` (add `-Editor` for the editor). The launcher creates its local `artifacts/` directory. Saves, generated captures/logs, engine binaries, caches and credentials are excluded from Git.

## What works

- A furnished coastal resort, broad beach, promenade, pool, café, reception, volleyball court, and fishing pier.
- Original transparent environment art, 16 reusable placeable Godot scenes, and matching illustrated female/male guests in eight directions. Complete painted walk frames replace the rejected walking warp.
- Seated meals, reclining, sleeping and couple volleyball rallies; an open cedar flower trough; separate furniture/court layers. See [the illustrated workflow](docs/assets/illustrated-guests-workflow.md) and `artifacts/walk-cycle-preview.png`.
- Independent terrain, scenery, buildings, and walking actors with depth sorting; animated surf and textured water.
- Building/decor placement, two cabin views, relocation/removal, stone path painting, placement explanations, and undo/redo.
- Shared rules for bounds, terrain, overlapping footprints, entrances, and routes back to arrivals.
- Full base containment shared by catalogue views, placement outlines and editor previews; upright, unwarped structures, distinct cabin entrances per facing and sunbed depth sorting.
- Pan/zoom, pause, 1× / 2× / 4× scene speeds, lighting previews, and a calm-water option.
- Versioned **layout** saving/loading with a previous-copy backup.
- Concurrent solo/couple bookings with varied budgets, interests and 1–3 nights; independent hunger/rest/enjoyment decisions, shared room reserves, split leisure and nightly reunion.
- Two-place cafés, sunbeds and volleyball courts with bounded queues, actual admission and per-person fees. Compatible guests can rally across different parties.
- Activity litter/spills, local cleanliness/mood, explained warning/grace departures, and up to three hired illustrated janitors who walk to and remove mess.
- Manage → Guests, Facilities, Staff and Operating results: inspect/follow any customer, see capacity and queues, hire/dismiss cleaners, and reconcile room/activity income against daily wages.

Default play shows real customers only. The live cap is twelve people including room waiters; the four starter cabins fit four parties, up to eight residents. The [living resort slice](docs/living-resort.md) explains tuning and scope. Construction cash, pricing controls, maintenance, fishing/swimming, progression, Creative controls, autosave and production save slots remain work. The original [first guest stay](docs/guest-stay-proof.md) survives only as an explicit compatibility/art fixture.

Guests waiting at the entrance are checking for an available connected cabin. They leave after 32 simulation seconds if none opens, without being charged. A world notice explains the queue and countdown; waiting positions keep their sprites apart.

## Controls

| Action | Control |
| --- | --- |
| Pan | Middle/right drag, WASD, arrow keys |
| Zoom toward cursor | Mouse wheel |
| Frame resort | Home / Home button |
| Inspect | Left-click visible object |
| Place | Choose an item, then left-click a valid footprint |
| Alternate cabin view | R / Rotate button |
| Move/remove | Select object, use inspector; Delete removes selection |
| Cancel tool | Esc / right-click |
| Paint paths | Paths tab, select lay/remove, click or drag |
| Undo/redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z |
| Placement grid | G |
| Pause scene | Space |
| Inspect / follow a guest | Click the guest, or Manage → Guests → select / Follow |
| Inspect facilities, hire cleaners, view finances | Manage menu |
| Save resort and live simulation | Ctrl+S / Save resort |
| Guide / beach view / light / calm water | Map guide / F1 |

The Play launcher stores edits in `artifacts/coastal-layout.json`; the prior copy is `.bak`. Direct Godot/editor play sessions use `user://coastal-layout.json` unless passed `--workspace-data`. Neither overwrites the authored starter map. To inspect the starter without loading your edits, run `tools/launch.ps1 -Fresh`. State is saved only when you use Save resort; this proof does not yet autosave.

Schema 4 saves population, routes, bookings, facility claims/queues, needs, dirt/jobs, staff, payroll and the transaction journal with the layout. It reads schema-1/2 layouts and schema-3 solo/couple stays, preserving old money/positions/deadlines without charging twice. Old cabin records retain their doorway. Migration in memory does not overwrite the source save; Save resort retains its previous-copy backup. Old layout-only saves start the new live population.

## Where to work

- `scenes/world/coastal_resort.tscn`: real terrain and object nodes, visible in the editor.
- `scenes/assets/`: individual building and scenery scenes.
- `assets/atlases/`: intact generated environment art; `assets/characters/`: original guest parts, retained experiments and baked frames; `assets/sprites/`: measured textures and guest SpriteFrames.
- `scripts/content/ground_registration.gd`: full base envelopes, solid-volume containment and upright source-to-grid placement.
- `scenes/validation/`: registered catalogue, guest frame sheet and playable walking preview.
- `data/coastal_map.json`: validated authored layout. Runtime changes stay in the working save.
- `scripts/world/resort_layout.gd`: map state, validation, navigation, layout persistence.
- `scripts/world/coastal_resort.gd`: camera, protected editing tools, real population, staff and management UI wiring.
- `scripts/simulation/living_resort_runtime.gd`: complete service envelope and transactional validation.
- `scripts/simulation/resort_simulation.gd`: bookings, individual routes/needs/decisions, spending, reunion and checkout.
- `scripts/simulation/facility_sessions.gd`, `cleanliness_system.gd`, `operating_ledger.gd`: physical capacity/queues, staff work/payroll, and deduplicated financial journal.
- `scripts/simulation/guest_stay.gd`: retained legacy solo/couple compatibility/art fixture.
- `scripts/content/cabin_interior.gd`: exact cabin layers and registered interior aisles.
- `docs/map-design.md`, `docs/assets/README.md`: map layout and asset workflow.
- `docs/game-design-brief.md`, `CONTEXT.md`: agreed product direction and vocabulary.

The `.tscn` editor preview and asset scenes are generated from the authored data and measured art. Runtime reconstructs the map from JSON. Make authoritative layout edits in the JSON or the running placement tools, rather than dragging a baked preview node and expecting its transform to update the logical grid.

## Validation / regenerate previews

From PowerShell in the project root:

```powershell
$enginePath = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
& $enginePath --headless --editor --path . --import
& .\tools\check-assets.ps1 -Engine $enginePath
& $enginePath --headless --path . --script tools/bake_assets.gd
& $enginePath --headless --path . --script tools/bake_map.gd -- --bake --fresh
& $enginePath --headless --path . --script tools/asset_manifest.gd
```

The asset gate checks source hashes, measured ground/entrance alignment, layout migration and placement rules, scene controls, walking silhouettes/stride timing and the reported sunbed clipping case using real GPU renders. It captures `artifacts/catalogue-registered.png`, `guest-frames-registered.png`, and `sunbed-occlusion-before.png` / `sunbed-occlusion-after.png`. Inspect those and an in-game view before recording reviewed sources with `tools/approve_asset_sources.gd -- --reviewed`. The expectations apply to future work through `AGENTS.md`.

To rebake models, run `tools/bake_structure_models.gd` and `tools/bake_guest_walk.gd` with a real renderer, reimport, and run the asset gate. Review before recording new hashes. Open `scenes/validation/walking_preview.tscn` and press F6 to see all eight facings. The [animated preview](artifacts/walk-cycle-preview.png) and [corrected game capture](artifacts/coastal-resort-corrected.png) are local review artifacts. The editable model is `scenes/assets/holiday_guest_model.tscn`; its native authoring source is `scripts/actors/holiday_guest_model.gd`.

The gate includes population/decision/facility/staff/ledger behavior, independent default-world acceptance, complete schema-4 save/resume and malformed cross-service rejection. Old single-stay and ambient checks run explicitly isolated legacy fixtures. GPU cabin/sunbed clipping and protected walk checks remain. Actual crowd/UI captures and measurements are recorded in [the living-resort QA record](docs/plans/living-resort-qa.md); these do not establish the planned 100–200-guest target. Broader work remains on the [roadmap](docs/roadmap.md).

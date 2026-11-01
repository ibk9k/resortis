# First inspectable guest stay

Extension: [ADR 0011](adr/0011-approved-illustrated-guests-and-couple-activities.md) adds illustrated female/male guests, solo/couple stays, seated meals, reclining, sleeping and volleyball. Couples share room charges and pay per person for activities; snapshot version 2 retains both routes and the activity clock. Older solo snapshots remain supported. The original solo proof below is retained as its baseline.

Implemented 2026-10-31. This extends the editable resort proof with one overnight customer, Maya. The fourteen other walkers remain ambient scenery actors.

## Play it

Use **Maya's stay** in the top bar, or click Maya. **Follow / stop** keeps the camera on her; dragging or Home stops following. Pause and 1×/2×/4× affect the same simulation. **Save resort** saves her live stay together with the edited layout. After she departs, **Welcome next guest** starts another demonstration stay. The optional launcher argument `--stay-view` opens her profile and follows her on launch.

Maya automatically chooses the closest reachable cabin she can afford for both nights. Its actual facing-specific door is the route destination. She enters along a measured aisle, checks in, rests, visits the café and sunbathing area, returns to her cabin, and checks out after two nights. Missing facilities produce an explained skip; missing accommodation produces an explained wait that retries when a cabin is added.

Working balance values for this proof, rather than final game tuning:

| Setting | Value |
| --- | --- |
| Planned stay | Two nights |
| Starting guest budget | $240 |
| Booking rate | $60 per night, fixed at reservation |
| Night duration | 180 simulation seconds after check-in / the previous night |
| Café visit | $12 for food and a drink |
| Sunbathing visit | $8 |

The first night is paid at check-in, the second at the following morning. Money for unpaid room nights stays in the guest's reserve. Activity purchases cannot consume that reserve. With the starter facilities, two nights, two meals and two sunbathing visits earn $160 and leave Maya with $80. The top bar reports revenue from this stay; it is not a resort cash ledger.

The profile shows current activity and its reason, interests, simple rest/hunger/enjoyment values, budget, reserve, paid nights, activity spending and recent events. The needs change with time and are replenished by the corresponding activity. Activity order is a deliberately small itinerary; a general needs-driven planner is future work.

## Room presentation

`CabinInterior` partitions each original cabin image into floor/rear walls, bed, desk and foreground edging. The eight derived PNGs in `assets/interiors/` contain every original pixel exactly once. Their import settings disable a second alpha-border correction. The source atlas and its geometry are unchanged.

Nested Y sorting places the independent furniture and foreground layers among world actors. Source-space aisle fixtures convert through `GroundRegistration` and `IsometricGrid`; there is no second projection or raster warp. The guest crosses the actual +X or +Y doorway and stays on a defined clear aisle. This is not unrestricted navigation among every bathroom/furniture item.

Regenerate after changing the cabin atlas or fixtures:

```powershell
$enginePath = '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $enginePath --headless --path . --script tools/bake_cabin_layers.gd
& $enginePath --headless --editor --path . --import
& $enginePath --headless --path . --script tools/bake_assets.gd
& $enginePath --headless --path . --script tools/bake_map.gd -- --bake --fresh
```

The cabin-layer metadata checks source and authoring hashes. Missing or stale layers fail clearly. Retain the committed PNG import settings. Review actual entry renders and run the asset gate before recording new reviewed hashes.

## Editing and saves

The reserved cabin cannot be moved, rotated or removed until the guest physically leaves it at checkout. Such edits are refused with an explanation; the player can retry afterward. There is no pending-edit queue yet. Facilities currently being approached or used are protected until that visit finishes. Undo/redo retains blocked history, and path edits preserve a route for the guest. Outdoor routes replan after accepted edits.

Layout schema 3 stores the live stay in the same atomic snapshot as objects and paths. It retains schema-1/2 loading, stable object IDs, old cabin entrance migration and the previous-copy backup. It validates the temporary snapshot before replacing the save. A malformed stay or layout cannot replace the open map. Old layout-only saves start a new stay. Test scripts bind separate `artifacts/test-*.json` files before startup; they never save the player's layout.

## Verification and remaining boundary

`tests/guest_stay_checks.gd` covers both cabin facings, complete stays, payments/reserves, mid-stay save/resume, missing facilities/accommodation, time-step equivalence, pause, picking/profile controls, occupied edits, blocked undo, corrupt loads and exact cabin pixel partitioning. `tests/cabin_occlusion_checks.gd` compares GPU torso pixels along both aisles against an unsplit-cabin negative control. Both run in `tools/check-assets.ps1` with the existing layout, scene, structure, gait and sunbed checks.

Evidence: `artifacts/guest-check-in-0.png`, `guest-check-in-1.png`, and `guest-entry-sequence-0.png` / `guest-entry-sequence-1.png`.

This is a deterministic one-booking proof, not the complete management simulation. The illustrated extension now adds seated meals, reclining, sleeping and couple volleyball; both partners save/resume together. Other needs, mood-driven/carefree early departures, 1–3-night variety, concurrent bookings, pricing controls, staff/dirt/wear, wages/upkeep, reviews, progression, missions, autosaves/manual slots, Creative transitions and scale profiling remain work. The existing bathroom art limitations also remain.

# Illustrated guest assets

The user-approved identity master is `assets/characters/illustrated-masters/guest-pair-v1.png`. Smooth illustrated female and male bodies replace the older native-model appearance. See [ADR 0011](../adr/0011-approved-illustrated-guests-and-couple-activities.md). All masters were authored with built-in ImageGen; exact prompts are retained beside this file.

Current inputs: the approved pair, female/male turnarounds, `female-walk-v3.png`, `male-walk-v3.png`, and `guest-activities-v1.png`. `female-walk-v2.png` is a rejected unguided sheet. Pixel and continuous-warp experiments are provenance only. Complete walk drawings are extracted by opaque component bounds, grouped into five rows of eight; equal generator cell spacing is not assumed.

Volleyball now uses **`guest-volleyball-v2.png`**, generated with built-in ImageGen: six complete authored poses per identity, from ready/crouch through forearm bump and follow-through. Exact prompt: [volleyball-hit-prompt-v2.md](volleyball-hit-prompt-v2.md). The old almost-static volleyball drawing in `guest-activities-v1.png` is retained for provenance; that sheet still supplies the other activities. `volleyball_hit_art.gd` isolates each connected body and alpha edge, uses one uniform scale across its six poses and registers the shoes. Both court facings mirror the entire drawing. No limb rotation or walking warp is used.

The four-second cycle retains sixteen phase slots: hit at slot0, follow-through1, recovery2, ready3–12, crouch13, drive14, contact15/0. The opposite player has the existing two-second phase offset. Contact metadata is measured on the actual extended hands in the hit drawing. A volleyball-only regeneration leaves all walking and other activity PNGs unchanged:

```powershell
& $enginePath --path . --script tools/bake_illustrated_guests.gd -- --volleyball-only
& $enginePath --headless --editor --path . --import
```

`tests/volleyball_hit_animation_checks.gd` rejects the former tiny wrist movement, checks visible arm/body travel, all 64 clean/grounded complete frames and actual rendered ball contact for either identity/side. `artifacts/volleyball-hit-preview.png` is a lossless four-second recording from the real naturally admitted rally. `volleyball-hit-compact-preview.png` records the same live world through a native 640×400 viewport for faster preview loading. Walking and the other activity outputs (328 files together) remain byte-identical.

Regeneration order:

1. `tools/capture_walk_pose_guide.gd` renders the protected old gait as an illustration guide. Generate revised walk art only when intentionally reauthoring it, using [the exact guided prompt](illustrated-walk-prompt-v3.md).
2. Run `tools/bake_illustrated_guests.gd` with the real renderer. Outputs live in `assets/characters/illustrated/{female,male}/{walk,activities}/`. `assets/registration/illustrated-guests.json` records input hashes and volleyball hand contacts.
3. Run `tools/bake_facility_layers.gd` if the sunbed source changes; the original image is partitioned without altered pixels. Native structure changes use `tools/bake_structure_models.gd`.
4. Reimport PNGs, then rebuild `tools/bake_assets.gd` and `tools/bake_map.gd -- --fresh --bake`.
5. Run `tools/check-assets.ps1 -PendingReview` while sources await review. This skips only the dated source-approval hashes. Inspect the catalogue, activities, both characters in all eight views and moving walk preview. Record approval only afterward with `tools/approve_asset_sources.gd -- --reviewed`, then run `tests/reviewed_asset_checks.gd`.

Review captures: `tools/capture_walk_cycle.gd`, `tools/capture_guest_activities.gd -- --fresh`, `tools/capture_npc_appearance.gd` and `tools/capture_npc_in_game.gd -- --fresh`. `node tools/pack-walk-preview.mjs` packages the unmodified rendered walk sequence as APNG. For volleyball use `node tools/pack-walk-preview.mjs artifacts/activity-preview artifacts/volleyball-preview.png 250`.

`tests/illustrated_skin_checks.gd` checks the real runtime textures against the exact source paintings, including the rejected distorted pose as a negative control. `tests/couple_stay_checks.gd` covers both cabin facings, activity views, distinct furniture slots, shared payments, JSON resume, speed equivalence and invalid partner routes. These complement the existing solo, layout, geometry, FPS and GPU clipping regressions.

Living-resort integration (2026-11-01): all **272 walking PNGs** were compared against their protected pre-change hashes and remain identical. Female NW and male SE court activities mirror their complete opposite-facing painting and hand contact metadata together, allowing either identity in either court slot. This changes no walking drawings. Real default play now renders the booking population; old single-stay captures explicitly opt into the compatibility/art fixture. Actual concurrent scenes are captured by `tools/capture_living_resort.gd`. Separate illustrated janitor sources/prompts and grounding checks are documented in `assets/staff/README.md`.

Solo playtest follow-up: sleeping presentation now aligns each unchanged full drawing's measured head landmark to its own pillow in either cabin facing/role. The logical hip destination/routes and raster scale remain unchanged. This is actor translation only, so existing character PNGs do not need rebaking. `tests/guest_pose_alignment_checks.gd` measures rendered head silhouettes against the atlas pillow centres; `tools/capture_pose_alignment.gd` supplies before/after and other-furniture evidence. See `docs/guest-pose-and-volleyball-fixes.md` for the original failure and verified natural-rally fix.

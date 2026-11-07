# Godot asset workflow

Current character workflow: [approved illustrated guests](illustrated-guests-workflow.md), following [ADR 0011](../adr/0011-approved-illustrated-guests-and-couple-activities.md). The native character and `frames-v2` below remain the protected gait guide and historical baseline; runtime appearance now comes from `assets/characters/illustrated/`. Couples sit/eat, recline, sleep and rally at volleyball. The rectangular planter is the newer open cedar model.

Original environment raster art was authored with the built-in image-generation tool on 2026-10-31. Source PNGs and exact prompts are retained. The second correction replaces the flat limb rig with an editable volumetric Godot character model and replaces the skewed net, bench and rectangular planter with modeled geometry. Godot renders these native sources into sprites using a fixed orthographic camera. No image-generation call was used to author the native models. The richer concepts remain the visual target; model material/detail polish is still needed to match the older raster art fully.

## Accepted runtime inputs

| Source | Contents | Prompt record |
| --- | --- | --- |
| `assets/atlases/buildings-v2.png` | Two cabin views, reception, café, sunbathing furniture | [Original buildings](buildings-sheet-prompt-v1.md), [spacing revision](atlas-spacing-fix-prompts.md) |
| `assets/atlases/props-v2.png` | Palms, round flowerbed, lantern, bin, rocks | [Original props](props-sheet-prompt-v1.md), [spacing revision](atlas-spacing-fix-prompts.md) |
| `assets/atlases/terrain-v1.png` | Grass, sand, paving and water material swatches | [Terrain](terrain-atlas-prompt-v1.md) |
| `assets/atlases/grass-wang.png`, `assets/atlases/sand-wang.png` | Sixteen Wang variants per material with matching painted edges | Regenerate with `tools/bake_terrain_wang.gd` and reimport |
| `assets/atlases/beach-v2.png` | Fishing pier; its old net image is unused | [Original beach facilities](beach-sheet-prompt-v1.md), [earlier net attempt](volleyball-net-correction-prompt-v2.md) |
| `assets/atlases/pool-v3.png` | Standalone pool with registered rectangular ground plane | [Pool correction](pool-grid-correction-prompt-v3.md) |
| `scripts/content/structure_models.gd` → `assets/structures/` | Upright volleyball net, bench, rectangular planter and bronze dolphin statue | Native editable Godot mesh construction; `tools/bake_structure_models.gd` |
| `scripts/actors/holiday_guest_model.gd` → `scenes/assets/holiday_guest_model.tscn` | One volumetric character with articulated limbs and an AnimationPlayer walk clip | Native editable Godot model; no raster-parts rig |
| `scripts/actors/guest_appearance.gd` | Sculpted face, layered eyes, swept bob, woven hat, clothing seams/pockets and smooth limb profiles | Native model art, separate from gait; `capture_npc_appearance.gd` and `capture_npc_in_game.gd` provide actual-scale review |
| `assets/characters/frames-v2/` | Eight directions × sixteen walk poses, plus eight neutral idles | `tools/bake_guest_walk.gd`; `assets/registration/guest-frames.json` |
| `scripts/content/cabin_interior.gd` → `assets/interiors/` | Exact floor/rear-wall, bed, desk and foreground partitions of both original cabin images | `tools/bake_cabin_layers.gd`; source/authoring hashes in `assets/registration/cabin-layers.json` |
| `tools/bake_facility_layers.gd` → `assets/interiors/` | Sunbed base/canopy partition and traced wooden café stool supports | Re-run the bake and Godot import after changing the buildings atlas or layer masks |
| `mockups/facilities/concept_models.gd` → `assets/structures/` | Eight editable inland facility models rendered at the registered world scale | Run `tools/bake_structure_models.gd -- --expansion`, import, then run `tools/bake_assets.gd -- --expansion` |

Earlier atlas versions, `guest-walk-*-v2.png`, guest-parts PNGs and the old `frames/` folder are retained experiments. The full-body sheets repeated poses; the flat articulated cutouts produced an unacceptable crossing gait. Neither supplies current animation. Their prompts and diagnostic pose guides remain for provenance.

## Facility ambience

Plan the occupied facility before generating the art. Record its employee or guest actions, props, idle environmental motion, access routes, contact points, and foreground objects. Give each pose and prop clearance in the source design. Keep the artwork, motion sources, and registration data together, and regenerate the complete placeable scene. Review the empty and occupied loops at gameplay zoom.

`FacilityAmbience` attaches to each placeable venue and is packed into its reusable scene. It registers the environmental effects against the structure art and masks the animated pool surface and waterfall against the original painting. Independent asset scenes play their own preview. The playable resort passes its simulation clock to every facility so pause, speed, layout edits, and loading stay in sync.

To regenerate the placeable scenes, run `tools/bake_assets.gd -- --ambience` to pack the affected scenes, then `tools/bake_map.gd -- --fresh --bake` to refresh the editor map. Run `tests/facility_ambience_checks.gd -- --fresh --capture-ambience` with a renderer for an in-game contact sheet and motion frames.

The six staffed venues use new building paintings in `assets/staffed-venues/masters/` and complete six-pose paintings in `assets/facility-staff/masters/`. `assets/staffed-venues/workstations.json` records each painted floor, employee anchor, service opening, foreground, guest fixtures, and environmental effect origins. The bake composites the working pose with the measured scenery into every full venue key. `FacilityStaff` times the keys on the resort clock. Existing visits keep their logical approach coordinates and register the drawn guest against the new chair, mat, or service point.

The ice cream vendor stands at ground level behind the wheeled stall. The counter covers her lower body, and the open service window keeps her face, arms, scoop, and cone readable. Guests stand along the front of the cart.

After editing a staff master, run `tools/bake_illustrated_attendants.gd` headless. After editing the building masters, measurements, or staff poses, run `tools/bake_staffed_venues.gd` headless and reimport the generated atlases. Pack the staffed scenes with `tools/bake_assets.gd -- --staff` and refresh the map with `tools/bake_map.gd -- --fresh --bake`. Use `tests/facility_ambience_checks.gd -- --fresh --capture-staff` with a renderer to review the six workstations.

## Ground registration and depth

`scripts/content/asset_library.gd` records measured alpha regions. `GroundRegistration` records the complete base envelope, including steps, rims and feet. Raster art uses uniform scale and translation, with an authored horizontal mirror where needed. Affine shearing, rotation and independent X/Y scaling are forbidden: forcing three floor points onto a diamond had tilted every upright part of several sprites.

Every solid structure must fit the vertical extrusion of its ground reservation. Runtime fitting scans the entire opaque silhouette against that volume, and the independent regression checks the resulting pixels. Vertical height may rise above the ground diamond; hard surfaces may not cross its side planes. Palm foliage alone may overhang at height; its complete ground base still fits. Flower pots, edging and planter rims have no exemption. Full base envelopes are checked independently of the opaque-pixel rule.

Modeled props render at 32√2 pixels per world unit with a 30° elevated orthographic camera: a world tile projects to 64 × 32 pixels, and Y-up poles project vertically. Their sprite transform is translation only. A test checks every physical mesh vertex against the catalogue XZ bounds. Exact sources are required; there is no silent atlas fallback.

Cabin facings have different real entrances: the southeast view uses the +X side, and the southwest view uses the +Y side. Path validation, entrance markers and layout migration use that same metadata. Selection overlays render beneath world objects. Object depth uses the footprint's ground centre, correcting the guest torso being hidden by sunbeds. Cabins now partition original pixels into independently sorted floor/rear walls, bed, desk and foreground layers. A measured clear aisle enables the first guest to enter and leave both facings. See [the stay proof](../guest-stay-proof.md) for regeneration and limits. Unrestricted interior traversal remains future work.

## Character authoring and runtime

The NPC detail pass replaces the placeholder face, dangling hair pieces, box shorts and hard cylinder joints. It adds shaped cheeks/chin, eye whites/iris/catchlight/lids, a softer nose and smile, a continuous bob with swept fringe, curved straw weave and ribbon, tailored shorts with rolled hems/pockets, tank-top straps/seams and smooth anatomical limb profiles. A softer character-specific light setup avoids hard hat/nose shadow cuts. These are native editable meshes and materials; no new raster generation was used for the pass. `npc-appearance-review.png` compares the previous model with the revision and includes gameplay size plus all eight views; `npc-in-game.png` shows the real resort render.

1. Edit `HolidayGuestModel`, a single volumetric character facing +Z before rotation. All facings share its proportions, face, hair, straw hat, clothes and sandals.
2. The gait solves two-bone legs of fixed length. Feet remain on their own lateral tracks; at least one foot is planted throughout the cycle. The swing foot lifts and returns while arms oppose the stride. The model includes an AnimationPlayer walk clip.
3. Run `tools/bake_guest_walk.gd` with a real renderer. It rotates the same model to S/SW/W/NW/N/NE/E/SE and renders sixteen poses plus idle per direction. Camera ground registration is asserted before baking. Outputs are isolated guarded PNGs and an editable packed model scene.
4. Reimport and run the asset gate. It checks fixed limb lengths, opposite lead legs, ground contact, feet not crossing, every direction, frame guards and connected silhouettes. Visually inspect the animated preview as well.
5. `ResortWalker` chooses eight-direction facing from movement and advances pose from distance travelled. Stride distance is calibrated from the model's stance foot travel and render scale; update it when changing those dimensions.

Open `scenes/validation/walking_preview.tscn` and press F6 for all eight animation directions; Space pauses it. `asset_review.tscn` and `guest_frames.tscn` provide the catalogue and pose sheet. Gameplay uses the baked SpriteFrames; the 3D model is the animation source.

## Acceptance and exports

Run `tools/check-assets.ps1` after source, ground, placement, navigation or actor changes. It checks measured alignment, all catalogue facings, actual entrance/path rules, saved-layout migration, connected/guarded walking silhouettes, opposite lead legs, frame-rate equivalence, scene controls and a GPU-rendered sunbed clipping regression. It also captures the catalogue and pose sheet.

Inspect the rendered catalogue, pose sheet, clipping before/after and a representative in-game view. Only after that review, record source approval with `tools/approve_asset_sources.gd -- --reviewed`. `reviewed_asset_checks.gd` rejects changes to registered sources or the relevant presentation scripts until they have been reviewed again. These checks reduce repeat mistakes; they do not replace visual judgment.

`tools/bake_assets.gd` regenerates sixteen reusable scenes in `scenes/assets/`, measured textures in `assets/sprites/`, and the guest SpriteFrames. `tools/bake_map.gd` regenerates the editor-visible map from authored JSON. Commands are in the root README. `AGENTS.md` makes this acceptance workflow applicable to future work.

## Current limits

The current [living resort slice](../living-resort.md) has concurrent real customers and illustrated janitors. The cabin bathroom nook depicts a shower and basin; a clearly readable toilet and final layout still need an art revision. Further pixel-density consistency, outfit variety, seamless material review, shoreline variation and audio remain work.

Current guest presentation uses actual furniture slots for seated eating, reclining, sleeping and opposite-side rallies. Default play has no ambient crowd. New janitor source paintings, exact built-in ImageGen prompts, uniform registration and bake commands are recorded in [the staff workflow](../../assets/staff/README.md). All 272 approved guest walking PNGs remain unchanged in this slice. Small-crowd performance evidence is in [independent QA](../plans/living-resort-qa.md); it does not prove the later 100–200-person target. Swimming/fishing, maintenance and pricing controls remain work.

## Provenance

No external sprite pack or paid asset was acquired. `asset-manifest.json` records PNG dimensions, hashes, source type and whether an image is a retained experiment or a current input/derived frame. `assets/registration/reviewed-sources.json` records the reviewed production inputs. Godot's bundled font is used in the interface. Distribution and final credits remain a release milestone.

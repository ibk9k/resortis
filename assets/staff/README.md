# Illustrated janitor

Worker 4's new staff-only type is Rina: cream polo, forest-green work cap and bib overalls, brown closed work shoes, gold badge, ochre cloth and a push broom during idle/cleaning. The same illustrated uniform is used for all three possible hires; names/identities are service data.

Both original alpha-transparent masters were created with the built-in ImageGen tool. Exact prompts are retained under `prompts/`. The approved `assets/characters/illustrated-masters/guest-pair-v1.png` is the style/proportion reference; the protected `artifacts/walk-pose-guide.png` is the gait reference. Neither was modified.

- `masters/janitor-walk-v2.png`: current five views × eight complete painted walking keys, with more distinct contact and passing poses. It was generated with built-in ImageGen against the protected pose guide and the existing janitor design. The [exact prompt](prompts/janitor-walk-v2.txt) is retained. The earlier `masters/janitor-walk-v1.png` remains as a reference.
- `masters/janitor-clean-v1.png`: five views × four complete planted-foot sweep paintings. The centered sweeping pose also supplies idle, with the broom held still.
- `janitor_art.gd`: measured alpha-component extraction, two-pixel source-edge guards, shoe-based root, uniform row scale, source hashes and runtime frame loader. The guard excludes disconnected neighboring broom-tip pixels without changing the retained painting.
- `janitor_skin.gd`: bake/review-only whole-picture presentation. Horizontal facing mirrors provide eight views; mirrored walking keys offset by half a cycle.

Runtime frames use a 256 × 256 canvas, root `(128,220)`, 200-pixel registered body height and uniform runtime scale `49/200`. Each walking key holds two of sixteen distance phase slots. Sweeping has four keys over 1.2 simulation seconds. The game samples the imported staff frames with the same linear filtering as the guest sprites, keeping facial features and uniform edges readable at normal zoom. There are no limb cutouts, walking warps or per-frame nonuniform scales.

The janitor takes two painted steps per 0.78 tiles walked, about three steps per simulation second at normal travel speed. A staff member on an active route keeps the current walk pose when no distance is added. Broom poses show while sweeping or waiting for work.

The coordinator runs the final bake and shared import from the project root:

```powershell
$enginePath = Join-Path (Get-Location) '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
& $enginePath --path . --script tools/bake_staff.gd --log-file (Join-Path (Get-Location) 'artifacts/staff-bake.log') -- --bake
& $enginePath --headless --editor --path . --import --log-file (Join-Path (Get-Location) 'artifacts/staff-import.log')
& $enginePath --headless --path . --script tests/staff_art_checks.gd --log-file (Join-Path (Get-Location) 'artifacts/staff-art-baked-checks.log') -- --baked
```

The bake writes only `assets/staff/illustrated/` (128 walk, 8 idle, 32 clean PNGs) and `assets/staff/registration.json`. It needs a real renderer. Exact measured source rectangles and source hashes are recorded in the registration. Pending registration/frames fail clearly in `CleanlinessView`; guest art is never substituted.

Use `-- --bake --walk-only` to rebake the walking frames and registration while retaining the existing idle and sweeping PNGs.

For review without baking or importing shared assets:

```powershell
& $enginePath --path . --script tools/bake_staff.gd --log-file (Join-Path (Get-Location) 'artifacts/worker-4-staff-preview.log') -- --preview-only
node tools/pack-walk-preview.mjs artifacts/worker-4-staff-preview artifacts/worker-4-janitor-motion.png 75
```

This renders all eight views at normal 49-pixel and enlarged 147-pixel sizes to sixteen frames in `artifacts/worker-4-staff-preview/`, plus exact measured `source-regions.json`. The APNG is a deliberately slowed pose review. Runtime walking uses actual route distance; actual world cadence/occlusion remains an integration review.

Source-only checks: run `tests/staff_art_checks.gd` without `--baked`. Source tests do not establish final runtime import or shared source approval. Coordinator owns the asset manifest, complete gate, integrated game render and reviewed-source record.

Coordinator integration (2026-11-01): baked/imported all 168 outputs and passed **640 baked/source assertions**. A native floor-line render exposed a thin broom outline being mistaken for a shoe; registration now requires a filled brown shoe patch. `tools/capture_staff_grounding.gd` and `artifacts/staff-grounding-review.png` show planted boots. Actual-world evidence includes `artifacts/living-resort-cleaning-closeup.png`; paid work is driven by real staff jobs, not a staged visual actor. The original masters/prompts remain unchanged.

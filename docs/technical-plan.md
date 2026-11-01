# Technical plan

Status (2026-11-01): the editable resort runs concurrent bookings, per-person needs/routes, shared facilities, cleanliness/jobs, janitors and a financial journal. `LivingResortRuntime` stages and validates the complete service envelope; `ResortSimulation` advances attached services once per 1/30-second shared step. Schema 4 saves the envelope atomically with the layout. `GuestStay` remains for old-save migration and explicit legacy/art fixtures. See [the living slice](living-resort.md) and [ADR 0012](adr/0012-living-resort-and-complete-snapshots.md). Broader systems below remain future direction where not explicitly implemented.

## Stack and setup

- **Engine:** pinned to standard Godot **4.7.2**, `4.7.2.stable.official.ed1daf0bf`, with typed GDScript. An existing local binary was copied into this project's ignored portable `.tools/godot` folder. No download or purchase was needed. [Official download](https://godotengine.org/download/windows/).
- **Renderer:** Compatibility successfully rendered the real scene on the available AMD Radeon RX 9060 XT. This verifies the first scene on this machine; it is not a broad hardware or 100–200-guest performance result. [Renderer guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
- **World:** textured native Polygon2D terrain, a combined path polygon, measured sprites and real actors share one 64 × 32 isometric grid. Cabin back/floor/furniture/front layers and actual aisles have GPU clipping regressions. TileMapLayer remains an option for later terrain authoring. [TileMapLayer guide](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html).
- **UI:** Godot Control nodes and themes, with text scaling independent of world pixel scale. [UI guide](https://docs.godotengine.org/en/stable/tutorials/ui/index.html), [resolution handling](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
- **Content:** typed custom Resources for the building, facility, decoration, guest-interest, mission, and balance catalogues. Keep definitions separate from each placed object's changing state; loaded Resources can be shared between instances. [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html).
- **Navigation:** evaluate AStarGrid2D on the logical ground grid, with explicit entrances and blocker footprints. [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html).
- **Persistence:** versioned local state snapshots, autosaves/manual slots, and a pre-Creative backup. [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html).
- **Assets:** original sprites/audio or suitable free/already-owned resources, with source information kept alongside assets. Image generation can support visual development; usable sprite consistency and animation must be demonstrated in-engine.
- **History:** Git for project changes; add LFS only when binary asset sizes warrant it. No backend is needed for the initial offline product.

Implementation check on 2026-10-31: Git and Node resolve in this shell. Godot is available by its project-local executable path. The portable `_sc_` marker keeps editor settings beside the copied binary. The supplied launchers save working map edits inside `artifacts`; direct Godot launches use the ordinary `user://` location. Source images/prompts, authored JSON, reusable asset scenes, an editor-visible coastal scene, and behavioral layout/scene checks are present.

## Simulation module and interface

Use a deep Resort Simulation module behind a small interface. Rendering, normal UI, Creative tools, and tests cross the same seam instead of changing guest/economy fields independently.

Proposed interface:

- **Execute an intent:** placement, relocation, prices, hiring/zones, Creative options, or a direct Creative action. Return a result with any failure reason and changes that presentation needs.
- **Advance simulation:** advance a defined amount of simulation time under the active rules.
- **Inspect:** read a resort/guest/staff view and explanations suitable for the UI.
- **Capture/restore state:** support persistence and repeatable validation through the same state model.

These are interface responsibilities, not final method names. Place internal modules where behavior concentrates: map/placement and access; guest stays/activities/needs; economy and bookings; staff tasks; goals/reputation; and mode rules. Keep simple behavior local until a real second use justifies another seam.

## Time and consistency

Use a controlled simulation clock separate from rendering and the Creative lighting override. Choose a simulation step after profiling. Interpolate actor presentation independently; path distance, task duration, and activity duration use simulation time.

Normal speeds and day skipping must advance the same rule implementation. Divide large advances into bounded work so the UI remains responsive. Define a stable order for nightly charges, guest decisions/departures, staff work, and day-close costs. Track processed guest-night and activity payments so resuming or skipping time cannot duplicate charges.

Use a seed and saved RNG state to reproduce scenarios within the pinned engine build. Godot exposes RNG state, while its underlying algorithm is an implementation detail; do not promise identical random streams across engine upgrades. [RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html).

## Placement and presentation

Current character presentation follows [ADR 0011](adr/0011-approved-illustrated-guests-and-couple-activities.md): approved illustrated bodies, eight walking keys over sixteen distance-based phase slots, matching male/female activities. ADR 0012 extends their use to concurrent bookings and adds separate illustrated staff. The native volumetric gait remains the protected pose guide. The continuous illustrated walking warp was rejected and is not a runtime input.

Keep the logical world grid independent of screen projection. A building definition supplies two authored views, footprint, entrance, terrain eligibility, service anchors, and visual layers. A placed record supplies identity, position, facing, condition, and prices.

Implemented presentation seam: `GroundRegistration` contains full raster bases and solid silhouettes using uniform scale/translation, while native modeled props render through one calibrated 2:1 camera. Raster affine warping is prohibited. Runtime, previews and baked scenes share this seam. Entrances are facing-specific; depth uses ground-centre keys, with overlays beneath objects. One volumetric guest model supplies sixteen poses plus idle in eight directions; fixed limb lengths and grounded stance are checked before baking. Runtime stride follows travelled distance with a calibrated foot-travel scale. `tools/check-assets.ps1` and reviewed-source hashes enforce this workflow. See [ADR 0009](adr/0009-upright-contained-structures-and-volumetric-guests.md).

Use explicit back/floor/interior/front layers where cutaway rooms need them; test guests crossing in front of and behind multi-cell structures. Fine decoration snapping does not bypass blocker/access checks. Clearly distinguish inland and beach eligibility.

Creative actions execute through the same placement and entity-lifecycle rules. Central mode options control waived costs/unlocks and the agreed needs/dirt/wear overrides. Keep unlimited money as a rule flag separate from a remembered finite balance. Disabling unlimited funds restores that value, including deliberate grant/set-money changes. Validate this through save/load and mode switching.

## Persistence

Snapshots contain stable identifiers, catalogue identifiers, parcel ownership, placed structures, guest/staff records, bookings/reserves, queues/tasks, economy state, goals/reviews, simulation clock/RNG state, and Creative settings. Scene-node ordering and visual animation frames are not the saved gameplay identity.

Capture a consistent state between simulation steps. Write a temporary snapshot, verify it, and replace the selected save while retaining a recoverable prior version. Store a format version and validate references on load. Define backup retention and migration before relying on long-lived saves.

## Meaningful validation

Exercise the module interface with actual scenarios: nightly payments and carefree departures; full/blocked facilities; dirt removed during an active staff task; occupied-unit relocation; save/load during a stay; Creative removal of a queued guest; and a day skip compared with ordinary advancement under identical initial state and overrides.

Profile 10-20 guests first, then representative 100-200-guest scenes. Measure path work, rule updates, drawing, memory, and high-speed simulation separately. Choose rendering optimizations or a different internal implementation only after a measured constraint warrants it.

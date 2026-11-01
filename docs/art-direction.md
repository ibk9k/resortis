# Art direction and first visual proof

Latest character direction: the user approved a smooth illustrated female/male pair. [ADR 0011](adr/0011-approved-illustrated-guests-and-couple-activities.md) supersedes the older volumetric-only appearance notes below. Complete guided walking paintings, restrained activity gestures and linear filtering preserve this appearance without the rejected mesh warp. See [the current workflow](assets/illustrated-guests-workflow.md).

Status: practical starting brief for visual development, based on the agreed [game design](game-design-brief.md). Exact pixel dimensions and final composition are determined by the proof.

The user selected **v1's richer detail** over the simpler v2 comparison. The [v3 revision](concepts/beach-resort-concept-v3.png) and exact prompts are retained. The first Godot asset/map proof now uses independent original sprites, a seventeen-row dry beach, furnished cabins in two views, a walking guest, and animated surf. See [asset workflow](assets/README.md) and [map design](map-design.md). User review and production-level consistency remain pending.

## Reference qualities to preserve

The supplied screenshots establish isometric diamond floors, cutaway furnished rooms, expressive people, strong small-scale silhouettes, detailed props, warm flooring/wood, lush greens, and readable activity in a dense resort. The user's later choice makes v1's richer texture, shading, foliage, and character treatment the preferred concept direction. Keep coherent pixel scale and clear silhouettes while following that choice rather than flattening the world to v2.

The screenshots establish appearance rather than movement or pacing. The [developer's game page](https://www.littlegiantworld.com/games/resort-empire/) links an [official trailer](https://www.youtube.com/watch?v=nA2DNF6wB3A). Motion/audio fidelity remains to be studied; the trailer has not been assessed in motion during planning.

## First concept frame

Create one original wide game-view concept showing:

- A single coast edge, breaking pixel-art surf, warm sand, and main resort grounds behind the beach.
- A broad, accessible band of dry sand, a sunbathing facility, and clear connections to inland paths. Provide enough length and depth for a properly scaled volleyball court, lounging, strolling, and the other planned beach activities.
- Complete cutaway cabins, reception, a small food/drink outlet, a pool, and a furnished garden area.
- Guests strolling, relaxing, using facilities, and visibly living in the resort; a janitor and maintenance worker read clearly at the same scale.
- A calm pixel-inspired HUD with readable money/time/mode controls, a grouped building catalogue, and a contextual guest profile. Show enough UI to judge its relationship to the world.

For the first composition, explore the ocean along the foreground-left diagonal edge and the resort behind/right. This is a preview composition choice, not a permanent selection of the map side.

The beach must read as usable resort land rather than a thin decorative strip. Show activity areas at a consistent scale with the buildings/people, retain comfortable circulation, and keep space between the surf and inland grounds.

Use warm sand/wood, saturated foliage, turquoise water, and controlled roof/fabric accents. UI panels can use dark muted green/charcoal, warm cream text, and restrained borders. The palette remains adjustable through review.

## Production asset rules

The concept establishes a target. A usable asset workflow additionally requires:

- One measured tile/projection standard and consistent object/character proportions.
- Two authored building orientations with matching footprint and entrance information.
- Repeatable sprite anchors and a clear separation of floor, wall, furnishing, and foreground layers where required.
- A character sheet covering the movement and interaction directions required by the first scene, with stable feet, head size, outline, and palette between frames.
- Terrain/shore assets that repeat cleanly and a short coherent surf animation.
- Consistent exports, transparent padding, frame names/durations, and editable source material.
- Correct appearance at native display size and supported pan/zoom settings, with readable UI text.

Generated concept imagery does not itself establish those asset properties. Validate a furnished room, vegetation, one character animation, and shoreline motion inside Godot before estimating a full catalogue.

The second correction prohibits affine warping: solid structures use full base envelopes and contained silhouettes with uniform scale, while the net, bench and rectangular planter are modeled against the real grid. A single volumetric guest model renders sixteen walking poses and idle in eight directions. Flat cutout rigs and repeated generated poses are retained experiments, not accepted motion. The asset gate checks containment, upright geometry, grounded gait, animation timing and the sunbed depth case. Cabins now use exact independently sorted art partitions and measured aisles; the first guest can enter both facings. A GPU regression checks the actual interior body pixels. Review the animated preview, catalogue and game view before approval. Detailed materials, final art consistency, broader room traversal and additional activity/staff animation remain visual development.

## First asset inventory

NPC appearance revision: the volumetric base now has sculpted cheeks/chin, layered eyes and smile, a continuous swept bob, a curved woven hat with ribbon, sewn tank/shorts detail and smooth tapered limb profiles. Character lighting keeps the face readable. Review at ~50 pixels, close up, all eight facings and in motion; `GuestAppearance` owns these visual choices separately from the gait. The richer environment art remains the consistency target; more guest identities and activity/staff art still need development.

| Group | Representative proof assets |
| --- | --- |
| Ground and coast | Inland floor, path, grass, sand, water, shore/foam segments |
| Accommodation | One furnished cabin with bathroom/shower access and two views |
| Operations | Reception, combined food/drink outlet, staff appearances |
| Leisure | Pool and sunbathing facility |
| People | Guest base and selected visual variants, janitor, maintenance worker |
| Scenery | Palm/tree, bush/flowers, planter, bench, small ground details |
| Feedback | Dirt/mess, cleaning/repair cues, mood indicator, selection/placement previews |
| UI | HUD frames, catalogue, guest inspector, basic finance/mission presentation, Creative panel |

This inventory supports the agreed first slice; beach volleyball and fishing belong to the wider initial-game catalogue after the representative proof.

## Review criteria

Compare the concept against the supplied references for camera, pixel density, character proportions, furnishing detail, palette, and overall resort atmosphere. Then review whether the new shoreline and calmer UI belong naturally in that world.

For the in-engine asset proof, check animation consistency, sorting at room corners/entrances, footprint and doorway alignment, shoreline repetition, and appearance during pan/zoom. User review sets the visual direction; the assistant owns iteration and asset preparation.

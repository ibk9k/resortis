---
status: superseded
superseded_by: 0009-upright-contained-structures-and-volumetric-guests.md
date: 2026-10-31
---

# Share measured ground registration and deterministic character poses

Historical first correction, superseded by ADR 0009 after further user review exposed tilted uprights, incomplete base containment and unacceptable cutout gait. Do not implement the affine mapping or flat character rig described below for new work.

The first asset proof used image-box anchors and one doorway for both cabin views. Floor outlines missed the visible ground plane, and an object depth key hid guest torsos beside sunbeds. Generated full-body animation sheets also repeated poses instead of exchanging the leading leg.

Every floor-bearing catalogue facing now has three measured source-ground points, transformed by `GroundRegistration` onto the common 64 × 32 logical grid. Point props have explicit contact pivots. The runtime, placement previews, diagnostic views and baked scenes use the same transform. Cabin entrances belong to each facing. Object depth uses the footprint ground centre, and selection overlays render beneath world objects. A schema-1 layout migration preserves objects/positions while selecting the cabin art matching the existing +Y entrance.

Character art is generated as separate original raster parts in four facings. A controlled Godot authoring rig joins those parts and renders eight walking poses plus neutral idle per direction into isolated guarded PNGs. Gameplay uses baked textures, with pose phase derived from distance travelled. The rendering rig is not a second gameplay clock.

Future asset changes must pass the asset gate and rendered visual review before source hashes are approved. Regression checks cover known ground offsets, real entrances and old-save migration, opposite lead legs, connected silhouettes, edge guards, frame-rate equivalence and the reproduced sunbed clipping case. Review records include the source art, registrations and scripts controlling their presentation.

This establishes the exterior asset seam. A whole multi-cell sprite still cannot correctly sort a guest inside every furnishing/wall; occupied-room traversal requires separately sorted interior layers. New activities, identities and staff need their own art and animation review.

# Coastal map: first Godot implementation

Status: implemented asset/map proof, pending the user's visual review. Source: `data/coastal_map.json`. Editor scene: `scenes/world/coastal_resort.tscn`.

## Layout

The main property is 44 × 48 logical tiles. World projection is 2:1 isometric with a 64 × 32 pixel diamond. The positive logical Y edge faces the sea, giving one diagonal coastline across the foreground-left of the view. Panning and zooming retain that camera direction.

| Zone | Logical rows | First composition |
| --- | --- | --- |
| Inland grounds | 0–20 | Four cutaway cabins, reception, café, pool, gardens, connected stone paths |
| Dry beach | 21–37 | Seventeen rows of usable sand; five sunbathing units, a full volleyball court, open circulation and expansion space |
| Wet sand | 38–39 | Visual surf margin, rocks; ordinary buildings cannot be placed here |
| Sea | 40 onward | Animated water and surf; fishing pier extends from beach row 36 |

The beach was widened again after the first real render. The court is set back from the surf, with walking space behind and in front. The fishing pier has its own shoreline placement rule. Ambient guests currently stroll on paths and sand, approaching the pier rather than walking on its raised deck.

The three rows of beach sunbeds nearest the promenade and two more near the shore show distinct layout possibilities. Building density remains small enough to assess the art and preserve inland expansion space. Rear/side palms outside the property are backdrop scenery, separate from editable placed objects.

## Editing rules

- Buildings use whole-tile snapping; garden props use half-tile snapping.
- Footprints remain inside the property and cannot overlap objects or paths.
- Accommodation and service buildings require inland grass. Sunbeds and volleyball use dry sand.
- The pier spans sand, wet sand, and sea, and must start on the shoreline row.
- Entrances need an actual route to the arrival anchor. An isolated path tile does not qualify.
- Path removal is rejected if it disconnects an existing facility.
- Object edits are reversible with undo/redo; saving writes a versioned layout and previous-copy backup.

Maya's first reservation now protects its cabin from move/rotation/removal until checkout; active facility use also protects that facility. Such edits must be retried after use finishes. Path edits and undo/redo preserve her access. Ambient walkers still rehome to reachable ground if an edit covers them; that is separate proof behavior. See [the first stay](guest-stay-proof.md).

## Rendering and authoring

The first terrain implementation uses textured native Polygon2D surfaces and a combined path polygon. Generated overhead material swatches are sampled in logical coordinates, keeping paths and ground coherent under the isometric projection. Surf is a separate Godot shader driven by the scene clock. This establishes the art and grid before choosing a larger terrain catalogue or TileMapLayer authoring workflow.

Placed sprites and walking actors share Y sorting using ground keys. Raster art uses full base envelopes and uniform scaling; all opaque solid geometry is contained by the vertical extrusion of its reserved tiles. No affine warping is allowed. The modeled net, bench and planter use the calibrated orthographic camera and have independently checked XZ vertices. Ground overlays sit behind objects. Both cabin facings now have independently sorted pixel partitions and a measured interior aisle.

The two cabin views use their actual +X or +Y entrance. Starter paths connect both facings. Schema 3 retains old cabin migration to +Y-facing art and saves the first stay with positions and identities. The pool, court and pier have registered ground planes. The raised pier's walking surface and broader facility traversal remain later work; ambient walkers stay on paths and beach, while Maya can enter her cabin.

`tools/bake_assets.gd` produces reusable asset scenes and texture resources. `tools/bake_map.gd` serializes the terrain and object nodes into the editor-visible map. The running editor tools share `ResortLayout` validation and rebuild presentation after accepted changes. The validated JSON is authoritative; baked node transforms are a preview.

`tools/check-assets.ps1` enforces full solid/base containment, upright transforms, per-facing entrance access, layout migration, eight-direction volumetric gait, distance-driven animation and the sunbed clipping regression. Inspect its catalogue and animated preview before approving source hashes. See [asset workflow](assets/README.md) and [ADR 0009](adr/0009-upright-contained-structures-and-volumetric-guests.md).

## Still to judge

User review of sprite detail and character scale; final pixel density and animation polish; shore shape variation, transitions and ambient audio; staff sprites and actions; broader interior traversal; expansion parcels and working beach activities. The wider management economy, reputation, prices, milestones, missions and complete Creative behavior remain on the roadmap.

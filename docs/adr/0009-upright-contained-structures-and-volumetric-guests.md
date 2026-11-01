---
status: accepted
date: 2026-10-31
supersedes: 0008-shared-asset-registration.md
---

# Preserve upright structures, contain solids and render one volumetric guest

User review found that the previous affine registration tilted poles/walls, while its corner tests merely verified the selected mapping. Point pivots did not constrain planter rims or bench feet. The flat cutout character rig also passed connectivity tests while still producing visibly unacceptable motion.

Raster structures now use complete ground envelopes and uniform scale/translation, with an authored horizontal facing mirror where required. Runtime fitting checks every opaque pixel against the vertical extrusion of the footprint. The independent regression checks those rendered positions and measured full base fixtures. Steps, edging, hard rims, roofs and furniture have no exemption. Palm foliage may overhang at height, with its ground base contained.

The net, bench and rectangular planter use editable native mesh geometry. Every XZ vertex must be inside the catalogue reservation. The shared orthographic camera projects ground to the existing 64 × 32 grid, with Y-up remaining screen-vertical. Rendered sprites use translation only. Court equipment overlays the existing beach texture.

The guest is one volumetric articulated model, rotated to eight directions. Fixed-length two-bone legs, separate lateral foot tracks, continuous ground contact and a real opposing half-stride replace the flat cutout rig. Sixteen walk poses and idle per direction are baked to guarded PNGs; a packed 3D scene and AnimationPlayer clip remain editable. Distance-driven gameplay phase is calibrated to the rendered foot travel. Camera root registration, limb length and stance are checked explicitly.

The old sources remain provenance experiments. Existing layouts, entrances, terrain rules and player object identities remain intact. Review must inspect the actual animated preview and a labelled catalogue whose grid does not obscure adjacent assets. Source approval includes the model code, render camera, registration metadata and current rendered frames.

Model geometry and motion are a production foundation; detailed materials and multiple guest identities remain visual development. Full guest stays and room interior sorting are still separate implementation work.

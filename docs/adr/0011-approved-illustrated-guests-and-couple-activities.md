# 0011: Approved illustrated guests and couple activities

Accepted 2026-10-31. The user explicitly selected the illustrated female/male pair and asked to replace the older character appearance while preserving sensible walking. This supersedes ADR 0009's volumetric-only **appearance** requirement; its structure/grid rules and protected gait source remain.

The first attempt attached one painted body to projected 3D joint motion. It failed: profile legs overlap in the painting and the deformation tore them, twisted sandals and stretched hands. Those outputs were rejected before runtime integration. Failed code and evidence are retained under `artifacts/rejected-illustrated-rig/`; they are not runtime assets.

Walking now uses complete illustrated bodies authored against a pose guide rendered from the unchanged `HolidayGuestModel`. Five authored views plus horizontal mirrors provide eight facings. Eight painted key poses are held across the existing sixteen phase slots. Uniform source registration preserves each painting's anatomy; there are no independently rotated cutout limbs or walking mesh deformation. This is a deliberate illustration workflow with fewer unique poses than the old sixteen-render cycle. The original `frames-v2` files remain a gait/reference baseline, not the accepted appearance.

Movement, route continuity, distance-based phase, pause and scene speeds remain in `ResortWalker`. The painted walk is reviewed in order and at actual game scale. Tests check distinct frames, guards, connected silhouettes and normalized source/render silhouette agreement; a rejected distorted frame is the negative control. Native gait checks continue to protect the pose guide, but do not by themselves prove painted foot contact.

Activity masters supply seated eating, reclining, sleeping and volleyball-ready bodies. Only small smooth wrist gestures and breathing deform these drawings; the displacement derivative is bounded and every triangle is tested for inversion/stretch. Feet and hands are not driven by the rejected walk deformation. Furniture fixtures use the shared registration transform. Cabin fixtures, the sunbed canopy and net/markings sort separately. The volleyball ball meets the rendered hand contact points and follows a timed arc.

One simulated booking now supports a solo guest or Maya and Leo together. Couples share the cabin price and pay for activities per person. Both route independently, wait for one another and use separate seats/loungers/bed positions. Couples rally across the volleyball net and walk around its post. Snapshot version 2 saves both routes and the shared activity clock; version 1 solo stays still load. This remains one booking proof, not concurrent resort simulation.

The rectangular planter is an open modeled cedar trough with inset feet, rim, soil, planks and flowering plants. Its complete geometry stays inside the 2×1 reservation. All structure containment requirements remain unchanged.

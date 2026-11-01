# Concept-frame refinement prompt

Method: built-in image generation, editing the first concept with the user's close-up and overview as style references. Target and references are preserved in docs/concepts and docs/reference-images.

## Prompt

Use case: style-transfer / faithful pixel-game concept refinement.

Input image 1 is the concept frame to revise. Input images 2 and 3 are the user's actual art-style references. Use 2 and 3 to control the pixel scale, character proportions, simplified shading, and cutaway building geometry. Preserve image 1's one-sided foreground-left beach, inland resort arrangement, wide game-view framing, and calm dark-green HUD placement.

Restyle the world much closer to the references: chunkier, flatter, sharply stepped hand-pixelled isometric sprite art. The tiny characters should have the references' oversized simple heads, compact bodies, short legs, and sparse facial pixels. They should be smaller and simpler relative to the world than in image 1. Use consistent enlarged pixel clusters throughout rather than fine painterly detail. Make floor tiles, beds, wooden walls, hedge shapes, and vegetation read as coherent modular game sprites with selective dark outlines and restrained shading. Aim for an early-2010s isometric browser resort tycoon look, with approximately 2:1 diamond floors and one fixed view. Retain a detailed, lively resort, but reduce microtexture and glossy lighting.

Keep the beach sunbeds/parasol area, furnished cutaway cabins, pool, reception, food/drink outlet, paths, planted gardens, janitor, maintenance worker, and guests using those places. Remove the ocean swimmers and floating toys from the sea; the pool can retain swimmers. Remove the surf-rental/surfboard display, the dog, and the ornamental waterfall, replacing those spots with simple vegetation or shore/garden details suited to the agreed slice. Keep the coastline itself lively with crisp pixel foam.

Keep the UI readable and understated, with pixel-inspired outlines/icons and clear text. Preserve the sparse labels: "MANAGEMENT", "DAY 3", "$12,450", "BUILD", "GUEST", "Mood", "Likes". The UI should feel quieter and clearer than the bright original reference UI; only the world art and character scale should strongly follow the references.

Do not add new facility categories or other animals. No smooth illustration, blurry resizing, photorealism, 3D-rendered surfaces, dramatic bloom, excessive tiny texture, watermarks, or branding copied from the reference game. The result is an original planning concept, not a recreation of the reference layout.

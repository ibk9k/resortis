# Atlas spacing corrections

Built-in image tool edits, with the current local atlas as the edit target. Original v1 files retained.

## Buildings v2

Use case: precise-object-edit

Repack this existing six-object sprite atlas for actual game use. Preserve the six exact object designs, pixel detail, camera, colors and transparency. Change only each object's scale and position so ALL of each sprite and shadow fits in its own equal cell. Canvas remains 1536 x 1024, exactly 3 columns by 2 rows of 512 x 512 cells. Shrink each sprite about 18 percent as needed. Every visible or semitransparent pixel for each object MUST fit within local x=45..467 and y=40..468 of its 512-square cell. Empty transparent padding on all four sides is essential. Cabin A, cabin B, reception across the top; café, pool, sunbeds across the bottom. Nothing may cross x=512, x=1024 or y=512. Preserve real transparency, no flat background, haze, backdrop or connected scene. No labels or grid lines. Do not clip or remove any furnishing, umbrella, post, waterfall or shadow. The pool's right post and the reception's bottom floor MUST stay inside their own cells. Retain rich crisp pixel art.

## Props v2

Use case: precise-object-edit

Repack this existing eight-object sprite atlas for actual game use. Preserve each of the eight exact designs, pixel detail, camera, colors and genuine transparency. Change only object scale and placement. Canvas remains 1536 x 1024, exactly 4 columns by 2 rows of 384 x 512 cells. Top: tall palm, small palm, hedge, flowerbed. Bottom: bench, lantern, bin, rocks. Keep every visible or semitransparent pixel inside local x=30..354 and y=30..470 of its cell. Shrink objects enough to fit, especially the first tall palm and the bench. There MUST be transparent padding on all four sides of each object. No sprite may touch or cross x=384, x=768, x=1152 or y=512. Align each object's ground contact near local y=450. No ground patches, connected scenery, text, dividers, haze or flat background. Maintain full silhouettes, rich crisp pixel shading and tight contact shadows; no clipped canopy or other parts.

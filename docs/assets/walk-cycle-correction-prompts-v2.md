# Guest walk-cycle replacements

Built-in image edits of the original guest sheet. Same identity in four dedicated sheets; eight frames each, one direction per sheet.

## Shared specification

Use case: identity-preserve
Turn the original character in the reference sheet into ONE coherent eight-frame walking cycle. Preserve the same woman, face, proportions, dark bob hair, cream straw hat with blue ribbon, coral sleeveless top, turquoise shorts, brown sandals, pixel-art outline/shading, and top-left light. Produce a 1536 x 1024 transparent sprite sheet, EXACTLY 4 columns and 2 rows of 384 x 512 cells, reading left to right then next row. One full person in each cell. Each cell has the same camera, the same body scale, the same center at local x=192, and the SAME ground-contact baseline at local y=450. Character height approximately 340 px, head/hat and torso retain stable proportions. Each whole person, including every foot and hand, MUST fit local x=75..309 and y=65..458, leaving wide transparent gutters. No shadows, labels, cell borders, duplicates, detached limbs, loose pixels, scenery, gradients, or crop. Every limb belongs to its own character and stays attached.

This must be an actual walking cycle, not eight nearly identical standing poses. Frames 1–8 respectively show left heel contact, left weight/down, right leg passing under body, right knee raised/up, right heel contact, right weight/down, left leg passing, left knee raised/up. Opposite arm swings naturally with the legs. Both legs visibly alternate between extended and passing poses, with a SMALL natural body rise/fall; do not slide both feet together. Keep a coherent planted foot baseline. Final frame flows naturally into frame 1. Fully opaque character pixels on a genuinely transparent background, stable clothing/face, no stray colored fragments between frames.

## se

Direction for EVERY frame: southeast, facing screen DOWN-RIGHT, a forward three-quarter view. The face looks toward bottom-right. No sideways or rear-facing frames.

## sw

Direction for EVERY frame: southwest, facing screen DOWN-LEFT, a forward three-quarter view. The face looks toward bottom-left. No sideways or rear-facing frames.

## ne

Direction for EVERY frame: northeast, facing screen UP-RIGHT, a rear three-quarter view showing the back of the head/hat and a small right cheek. No front-facing frames.

## nw

Direction for EVERY frame: northwest, facing screen UP-LEFT, a rear three-quarter view showing the back of the head/hat and a small left cheek. No front-facing frames.

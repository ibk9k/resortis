Use case: identity-preserve
Use the woman in the supplied reference as the exact character design. Create a game-animation BODY PARTS atlas, not a walk-cycle sheet, on a genuinely transparent background. 1536 x 1024 canvas, EXACTLY FOUR COLUMNS and TWO ROWS, eight equally sized 384 x 512 cells, one completely separate part per cell. Transparent padding around every part. No labels, grid, backdrop, duplicates, shadows, or complete people. The parts will be joined by the game engine to make an articulated character.

Preserve her crisp rich pixel-art style, straw hat with blue ribbon, dark bobbed hair, coral sleeveless top, turquoise shorts, warm skin, sandals, face, camera and light. Each part must be fully drawn with clean rounded attachment ends; no ragged amputation, bones, gore, or black cut lines. Limb attachment ends are plain skin with soft rounding, so overlapping them makes clean joints. This is a friendly modular sprite kit.

Reading-order cells:
1. HEAD: her full straw hat, ribbon, dark bob hair, face and a tiny neck tab, nothing below the neck.
2. TORSO: her coral top, neck base, complete turquoise shorts/waist/hip area, but NO head, arms or legs. Empty short leg openings with short overlapping skin attachment tabs are fine. Preserve proportions and clothes.
3. LEFT ARM: one whole bare arm from rounded shoulder to attached hand, almost straight and pointing DOWN. No sleeve, torso, second hand, or other body parts.
4. RIGHT ARM: the other whole bare arm from rounded shoulder to hand, almost straight and pointing DOWN. Same skin, thickness and pixel scale as left arm.
5. LEFT THIGH: one bare upper leg, straight DOWN from a smooth rounded hip attachment to a rounded knee attachment. No shorts, foot, calf, other limb or body.
6. RIGHT THIGH: the other bare upper leg, straight DOWN, same length and thickness as the left. Rounded hip and knee attachments.
7. LEFT CALF AND FOOT: one lower leg pointing DOWN from a rounded knee attachment, with her complete sandal and foot attached at the bottom. Sandal/toes point in the character's specified camera direction. No thigh, spare foot or other body.
8. RIGHT CALF AND FOOT: the other lower leg pointing DOWN from knee, with her complete matching sandal and foot attached. Same scale as left calf.

Treat the limb silhouettes as animation-ready cutouts with enough overlap at joints. Every piece must fit fully within its own cell, local x=50..334,y=40..470. Pieces may have different total size within the cells; do not fill every cell with an equally large body part. Head roughly 250 pixels tall, torso 210, arms 210, thighs 140, calf-plus-foot 170. Keep each long limb's axis vertically downward on screen, not diagonal. Keep transparency truly empty between all pieces. Draw the same original character, not a new character or different outfit. No solid background.

## Exact suffix appended for each facing

`ALL EIGHT PARTS use this facing: {description}. Limbs remain vertically downward in their own neutral cutout cells.`

- se: `front three-quarter facing DOWN-RIGHT (southeast), her face visible`
- sw: `front three-quarter facing DOWN-LEFT (southwest), her face visible`
- ne: `rear three-quarter facing UP-RIGHT (northeast), back of hat/hair and shirt visible, only a tiny cheek`
- nw: `rear three-quarter facing UP-LEFT (northwest), back of hat/hair and shirt visible, only a tiny cheek`

Reference: the original generated guest design. Tool mode: built-in image generation with identity reference and transparent background. Output sources: `assets/characters/guest-parts-{se,sw,ne,nw}-v1.png`. Source components are measured after generation rather than assuming the requested equal-cell layout was obeyed exactly.

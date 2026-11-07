# Guest placement and volleyball follow-up

2026-11-01. User reported that the two illustrated guests lay at different incorrect places on the bed and that volleyball was absent during ordinary observation. This follow-up was done solo, after the earlier six-worker slice.

## Reproductions and causes

`tools/capture_pose_alignment.gd` renders both identities in both bed roles and cabin facings. `tests/guest_pose_alignment_checks.gd` measures the head silhouette in the actual runtime PNG through the actual actor transform against independently measured pillow centres in the building atlas. All eight combinations failed before the fix, by 3.62–6.76 native pixels. Distinct logical bed slots alone had not established that the paintings rested on their pillows.

The later resting-position adjustment centers reclining guests on the lounger cushions and uses a smaller uniform scale. Café seating registers each guest's contact point against the measured top of each stool. Following the user's feedback, seated guests use their complete, unmasked artwork without a stool or counter foreground layer. Cabin head checks target the headboard side of each measured pillow and cover both cabin facings. Lounger centerlines and seat contact are checked for both guests and positions.

The sleeping drawings used different guessed hip pivots. Furniture placement knew nothing about their head landmarks. Sleep presentation now registers each unchanged whole drawing to its own measured pillow. Movement destinations, routes, saved positions, artwork, scale and distance-driven walking remain unchanged. Rendering returns to the ordinary root/scale for other poses. Both permutations and cabin facings were inspected, along with seated meals and loungers for both identities/roles.

`tools/probe_volleyball_traffic.gd` runs the unmodified authored starter with real needs, bookings, movement, claims and fees. Before the fix, there was one court request and **no rally in 360 simulation seconds**. A social-choice probe then attracted a second player: Leo waited from 74.43s, another guest committed at 89.7s, but the first reservation expired at 96.43s, well before the opponent could finish the physical route. The renderer was capable of rallies; normal decision/admission timing was the blocker.

Offers now report real visitors seeking a game, so a sufficiently rested/fed guest who wants leisure can choose to join. Urgent needs and protected room money still win. A truly lone visitor retains the 22s timeout. Once an opponent commits, the waiting reservation respects that opponent's existing bounded 90s arrival deadline. The facility service owns this timeout; the population no longer independently ends external waits after its old 22s countdown. Readiness, actual arrival and atomic two-player payment remain required.

An additional regression caught restoration of that extended wait being rejected: ticket validation checked the first player's deadline before considering the other saved ticket. Restore now decodes/validates all ticket shapes and references, then evaluates deadlines against the complete staged peer set before committing. Missing opponents still expire and failed restores remain transactional.

## Evidence

- Before/after: `artifacts/bed-alignment-before.png`, `bed-alignment-after.png`; native default sleep: `living-resort-solo-fix-sleep-closeup.png`.
- Other furniture: `artifacts/bed-alignment-seating-review.png`.
- Actual naturally chosen rally: `artifacts/living-resort-solo-fix-volley-motion-00.png` through `39.png`, plus overview/closeup and tagged JSON report. The ball is visible crossing above the net. `artifacts/volleyball-natural-preview.png` losslessly packages the full four-second sequence at its actual 100ms cadence; the packer accepts optional frame count40 while retaining default16 for existing walks.
- Fixed natural starter: first court request 59.3s, first rally **124.9s**, between actual people 2 and 5. Full-envelope JSON restore during the extended paired wait passes. This is a seeded observation, not a guarantee that every edited save starts a match at that exact time.
- Focused regressions: `tests/guest_pose_alignment_checks.gd`, `tests/volleyball_arrival_checks.gd`, and the natural traffic probe are included in `tools/check-assets.ps1`.

Earlier acceptance demonstrated possible rallies using controlled demand and protected separate slots; it did not protect natural first-day volleyball visibility or actual head-to-pillow placement. The new checks target those missing seams. No character master or walking PNG was changed.

The changed choices also removed the previous incidental early queue. A 600s natural observation did not see that queue; it is recorded honestly in `living-resort-solo-fix-queue.json`. The Save/restart regression now replays the real previously recorded 135.6s queue from `tests/fixtures/occupied-facility-queue.json`, asserts a physically waiting guest, and checks actual Save/restart/future state. Claims, movement and money are original observed data. No queue assertion was removed and no ticket was fabricated.

Final solo verification: 596 population, 668 decision, 951 facility, 75 live-save/file checks; 187 actual-world assertions; combined independent harness **2,877 assertions, zero failed or pending cases**. New pillow, bounded paired-arrival/restore and natural first-day rally checks pass. GPU cabin and sunbed regressions again show zero hidden body pixels. A read-only probe of the existing player save also starts a real rally after **148.1 additional simulation seconds**, and observes a second match. All **272 walking PNG hashes remain identical**. Current captures and reviewed-source hashes were refreshed after visual inspection; tests did not overwrite the player save.

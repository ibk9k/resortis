# Living resort slice

Implemented from the user's nine-change, six-worker plan approved on 2026-11-01. The approved illustrated guests and their distance-driven walking are preserved. This is the first concurrent management slice, with construction cash/pricing/progression still ahead.

## Play and inspect

Launch `Play Resortis.cmd`, or F5 in Godot. Every visible customer belongs to a booking. Click a customer or open **Manage → Guests** to select/follow them and see their needs, reason, interests, room reserve and shared spending. **Facilities** shows occupants and queues; **Staff** hires/dismisses cleaners and explains cleanliness/wages; **Operating results** reconciles room/activity receipts and payroll by day.

The starter has four cabins: four resident parties, at most eight resident people when every party is a couple. The live cap of twelve includes room waiters. A valid six-cabin QA layout exercises the 8–12 accommodated-person target without changing the starter or the player's layout. Waiting visitors leave with a reason after 32 seconds without a room.

## Guest and facility rules

- First party: Maya and Leo, two nights, $480 shared budget. Later profiles vary names, male/female appearance, interests, budget and 1–3 nights; arrivals are 20–29 simulation seconds apart.
- One resort day is 180 simulation seconds. A room costs $60 per cabin/night, shared by the couple. Activity spending cannot touch remaining booked-night reserves. Nightly charges/release wait for physical reunion/checkout.
- Hunger, rest and enjoyment recover in actual activities, rather than while merely walking toward them. Choices consider urgency, interests, price/reserve, reachability and queues. Couples may accept invitations or choose separate leisure, then reunite at their own cabin for nights/checkout.
- Café, sunbed sets and courts each have two physical places and up to four safe FIFO waiters. Queue timeout 55s, reservation timeout 90s, unpaired court timeout 22s; paid sessions are bounded at 60s. Exiting people hold furniture until physically clear. Queue stations must leave all entrances connected.
- Meals cost $12, sunbathing $8 and volleyball $10 **per admitted person**. Guests reach the actual fixture before charging. Court players both arrive and can both afford their fees before either is charged. Cross-party matches use opposite court slots and the same rally clock.
- Guests can notice another visitor seeking a game. A lone court wait remains 22s; after an opponent commits, their bounded 90s reservation supplies time to walk there. The facility service owns that timeout and restores the complete pair before validating deadlines. See the [solo placement/volleyball follow-up](guest-pose-and-volleyball-fixes.md).
- Ordinary seated preparation is 3s, eating 12s, reclining 18s and a rally 20s. These are reversible prototype tuning values, not a finished balance.

## Dirt, mood and staff

Completed meals/sunbathing/rallies can leave local mess (probability .65/.35/.40). Meal mess is a spill 40% of the time. At most 32 marks and eight per facility are retained. Cleanliness falls within 4.5 tiles, weighted by distance and dirt type (litter 19, spill 24). It is a local score, not an invented global reputation.

Severe mood at or below 28 persists for 18s before an explained warning, then a 30s grace period precedes an early-departure request. Recovery to 43 clears the warning. The party still exits/reunites physically; it is not deleted where it stands.

Hire up to three janitors, with no upfront fee. Each costs $30 at each completed 180s global day boundary while hired. A hire exactly at the boundary starts afterward; late-day hiring uses the same published boundary convention. Dismissal stops future wages and releases work. The ledger retains lifetime wages, including dismissed staff.

Janitors claim the nearest reachable unclaimed mess, walk at 1.2 tiles/s, reach within .5 tiles, then sweep litter for 4.5s or spills for 6s. Claims are exclusive and survive valid saves; blocked edits are rejected. New illustrated cap/overalls/broom art is isolated under `assets/staff/`; original alpha masters and exact ImageGen prompts are retained there. Foot registration uses filled shoe patches so a thin broom outline cannot raise the body above the ground.

## State, editing and money

`LivingResortRuntime` owns configured population/facilities/cleanliness/ledger references. The population advances them once on the shared fixed step. Presentation reads that state; panels emit actions and never maintain separate gameplay values. Stable person/party/staff/transaction identities are independent of scene nodes.

Schema 4 stores the complete envelope with the layout: RNG, clock/remainder, routes/distance, bookings, deadlines, needs/mood/warnings, paid visits, queues/held claims, dirt, jobs/cleaning progress, staff and the deduplicated ledger. Restore stages every service, validates bidirectional ownership and exact money/receipt metadata, then swaps atomically. Malformed loads leave the open map/runtime unchanged. Normal Save retains the prior-copy backup.

Schemas 1/2 layout-only and schema-3 solo/couple stays migrate in memory. Old positions, route phase, budgets, paid nights and deadlines persist. Historic aggregate activity income is labelled **Earlier activities** rather than fabricated as specific meals. Migration never charges again or overwrites the source file automatically. No autosave is introduced.

Cabins remain reserved through physical checkout. Committed facilities, queues, all current customers and staff constrain moving/removal, path edits, placement and undo/redo. Valid unrelated edits replan routes without resetting distance phase. Rejected edits preserve history.

## Verification and limits

The complete regression entry point is `tools/check-assets.ps1`; `-PendingReview` omits only the deliberately stale art-approval hash until visual review. Independent scenarios/results are recorded in `docs/plans/living-resort-qa.md`. Worker ownership/handoffs and baseline recovery live under `docs/plans/` and `artifacts/living-resort-baseline-2026-11-01/`.

Final source review accepts 774 hashes after actual catalogue, walk, activity, staff/motion and live UI review. Complete old/new gate passed; later targeted checks include 73 real file/save assertions and 186 independent actual-world assertions. GPU cabin/sunbed regressions report zero hidden body pixels. Ten accommodated customers plus one cleaner sustained 600 frames at each 1x/2x/4x; wall p95 was 17.014/6.248/6.565 ms and world CPU p95 .937/.736/.938 ms on this AMD RX 9060 XT machine. These are measured samples including OS pacing, not guaranteed FPS or larger-scale claims.

`tests/living_mood_checks.gd` isolates the combined dirt boundary with a fully validated saved fixture: a checked-in outdoor walker waits on an open beach patch with eight pre-existing reachable spills and healthy needs. Real runtime score produces a warning after 18s. Three actually hired janitors walk/clean six marks; while the guest remains at the same position, mood rises 24.9→64.5 and the warning clears within grace. W6 independently reran and accepted this controlled integration fixture. A separate 1200s natural sample accumulated 16 marks without the severe dirt-only warning and is retained as `artifacts/living-mood-natural-probe.json`.

No maintenance/wear, fishing/swimming gameplay, new building catalogue, construction-cash economy/loans, pricing controls, reputation/missions/progression, thirst/hygiene, full Creative powers, autosave or manual-slot UI are included. The janitor uniform is one illustrated type reused across hires. Small-crowd measurements do not establish the later 100–200-person target.

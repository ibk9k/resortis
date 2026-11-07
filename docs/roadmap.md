# Development roadmap

Status: milestone-based plan for the agreed game. No calendar deadline or unmeasured completion estimate is assumed. See the [design brief](game-design-brief.md), [art direction](art-direction.md), and [technical plan](technical-plan.md).

## 0. Foundation: core direction recorded

The core product, guest/economy/staff rules, coastal setting, Creative policies, provisional 100-200-guest target, and 10-20-guest first slice are agreed. Detailed mission, balance, and save-transition rules are refined when their implementation becomes concrete.

Output: the design brief, glossary, decision records, and this plan. The accidental `/find` command has been clarified and does not require search work.

## 1. Visual and asset proof

Study the reference in motion, create the first concept frame, and iterate against the supplied screenshots. Validate original assets in a small Godot scene, including one furnished cabin, two building facings, a character animation, coastline motion, depth sorting, and an example of the agreed UI.

Current progress (2026-11-01): seventeen dry-beach rows, 16 reusable placeable scenes, two cabin views, animated water, protected editing/paths/undo and complete live saves. Illustrated female/male customers walk, eat seated, recline, sleep and rally at volleyball; illustrated janitors walk and sweep. Both cabin facings have independently sorted layers and traversable aisles. Upright modeled props and solid containment remain enforced. Further art consistency, reference-motion study and audio remain work.

Pass when the user agrees on the look and the assets demonstrate a repeatable, consistent workflow at actual game size. A concept image is an intermediate visual target; animated in-engine assets establish production feasibility.

## 2. Functional guest loop

Implement a small map, placement/access rules, automatic booking, 1-3-night stays, nightly payment/reserves, facilities charged per use, the selected needs/interests, and clear departures. Add janitor cleanup and maintenance work through the same evolving simulation.

Historical first stay: Maya selected an affordable reachable cabin, entered its actual door, paid two nights, visited café/sunbathing and checked out. Its schema-3 snapshots, both facings and GPU clipping tests are retained as compatibility/art fixtures. See [the first stay proof](guest-stay-proof.md) for that earlier boundary; the live slice below supersedes it.

The [living resort slice](living-resort.md), approved on 2026-11-01, replaces ambient walkers with concurrent real bookings, varied budgets/interests and 1–3-night stays. Individual needs drive leisure; two-place facilities queue/admit/charge physically. Couples split leisure and reunite for nights/checkout. Local dirt/mood and warning/grace departures, hired janitor work/payroll, management panels and an operating ledger are implemented. Schema 4 atomically saves every service and migrates old stays. See [ADR 0012](adr/0012-living-resort-and-complete-snapshots.md) and [independent QA](plans/living-resort-qa.md). Next: user playtesting/balance, then maintenance/wear and the wider financial recovery/management loop under a new agreed scope.

Pass when guests can complete a stay, use the services that meet their needs, pay correctly, and either leave normally or explain an early departure. Blocking/editing paths must produce defined behavior rather than stranded agents.

## 3. Management and progression

Resort cash, catalogue and path purchases, daily upkeep and janitor wages, editable guest prices, and the profit-and-loss statement with receipts are implemented. See [ADR 0013](adr/0013-resort-cash-and-prices.md). The [challenge board](missions.md) has three untimed goals and one optional timed challenge with cash rewards and a bronze dolphin statue. Add overall appeal, guest reviews/reputation, milestone unlocks, purchasable parcels and the recovery loan/guidance design.

Pass when construction, staffing, and pricing create understandable consequences, successful operations enable growth, and a zero-cash/zero-arrivals resort has a viable recovery path. Mission types and rewards must have explicit criteria and completion behavior.

## 4. Creative tools and durable saves

Local autosave and six separate manual slots are implemented, including backup recovery and validated in-game loading. Add the agreed any-save mode switching, pre-change backup, preset/granular powers, live-simulation overrides, day skipping, lighting control, and extra tools. Restore remembered finite cash, including deliberate grants, when unlimited funds are disabled.

Pass when saves round-trip meaningful state, mode switching retains the edited resort, direct Creative changes leave no orphaned bookings/jobs/queues, and day skipping processes events consistently with normal simulation.

## 5. Polished first playable slice

Bring the agreed small coastal resort to representative quality: reception, one cabin type, food/drink outlet, pool, sunbathing, both hired staff roles, and 10-20 guests. Integrate the UI, surf/ambient audio, activity feedback, onboarding, Management goals, and Creative tools.

Pass when the user can play and diagnose the resort through the interface, construction and observation are enjoyable, the presentation meets the agreed art target, and meaningful regression checks pass. Collect findings before enlarging the catalogue.

## 6. Initial game catalogue and scale

The starter now includes eight operating inland venues and 22 additional buildable rows. See [the layout and venue capacities](map-design.md).

Expand content, progression, missions, decoration variety, and the initially requested beach volleyball/fishing. Profile representative 100-200-guest scenes and higher simulation speeds; set measured budgets and choose optimization work from the results.

Pass when the larger resort remains readable, responsive, and stable, goals/reviews/economy remain coherent, and the asset workflow sustains the required content quality.

## 7. Release preparation

Finish accessibility/settings, save/update compatibility, playtest-driven balance, source/credit records, packaging, and release-specific requirements. Steam remains a possible distribution route; release arrangements are separate from the zero-new-spending preproduction phase.

Release criteria follow the measured game and completed catalogue. Other locations, day visitors, and editable accommodation interiors remain later possibilities.

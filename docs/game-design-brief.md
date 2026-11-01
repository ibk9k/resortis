# Beach resort game: working design brief

Status: core direction and first playable-slice scope agreed. Preproduction now moves toward the reference study and visual/style proof; detailed rules and production capacity still need validation. Detailed discovery is in [preproduction.md](preproduction.md), vocabulary in [CONTEXT.md](../CONTEXT.md), and consequential decisions in [docs/adr](adr/).

Execution planning: [technical plan](technical-plan.md), [art direction and first proof](art-direction.md), [milestone roadmap](roadmap.md), and [Creative mode](creative-mode.md).

## The experience

Build a charming isometric pixel-art resort behind a sandy beach, watch individual guests enjoy it, and improve its performance through layout, decoration, pricing, and staff coverage. The main game follows one property that grows over time. Financial setbacks remain recoverable, preserving the player's investment in the resort.

The supplied Resort Empire screenshots are the close visual reference: crisp pixel art, cutaway furnished rooms, small expressive characters, lush landscaping, and dense readable detail. The world should keep that visual language using original assets. The UI uses pixel-inspired frames/icons with clearer scalable text and calmer colors. Gameplay pacing, audio, and movement fidelity still require reference study and a representative proof.

The user selected the richer visual detail of concept v1 over v2, with a substantially more spacious beach. Preserve v1's character and environment treatment while providing credible room for volleyball, sunbathing, fishing, and circulation.

## Platform and production

- Paid public Windows PC game, with mouse-and-keyboard input; Steam is a possible storefront.
- Godot 4 with typed GDScript. Pin and validate an exact stable release during setup.
- User directs and playtests; assistant handles implementation and develops the asset workflow. No hired specialists or user-performed pixel cleanup are assumed.
- Preproduction has zero new spending and no fixed deadline. Use free or already-available resources and quality milestones.
- Single-player offline, local autosaves, and manual save slots. Cloud synchronization is a separate later decision.

## Building the resort

Place complete furnished accommodation units, each providing basic bathroom and shower access. Interior customization is a possible later feature. Buildings and paths snap to the main grid; small decorations use finer snapping. Existing items can be moved free, while changes affecting occupied accommodation wait until checkout. New construction retains its purchase cost.

The camera stays in one isometric viewing direction, with pan and zoom. Larger buildings initially have two authored orientations. Exact pixel scale, tile dimensions, facings, footprints, overlap rules, and supported zooms will be established through the art guide and tests.

Decoration contributes both local appeal around accommodation and overall resort appeal. The exact business effects remain to be designed, keeping scenery attractiveness distinct from a guest's mood and from reputation based on guest feedback.

## Beach and expansion

The sea and sandy shore run along one of the map's four sides; the exact side is open. Animated surf establishes the shoreline, with the main resort behind it. Guests can stroll and relax on the beach freely. Placed beach facilities charge individually per use.

Beach-specific facilities and outdoor decorations can be placed on sand, while ordinary cabins and shops initially remain inland. Volleyball, sunbathing, and fishing areas are included in the initial game scope. They do not imply swimming, boating, or physical water simulation.

Resort milestones unlock advanced buildings/decorations and adjacent land parcels, which are then purchased. The same expansion structure applies to inland and beach parcels. Essential services are available from the start; the exact starting catalogue and milestones remain to be designed.

Management has a long-term goal of reaching a prestigious top-tier resort status, followed by continued free play. Side missions appear on an optional mission board, mostly as untimed goals with occasional optional timed challenges. Rewards include in-game cash or decoration variants. Exact prestige criteria, mission definitions, reward amounts, and repeatability remain to be designed. See [missions.md](missions.md).

## Guests and operations

Initial guests stay overnight; day visitors are a possible later feature. Planned stays vary from 1 to 3 in-game nights. Guests choose available accommodation automatically based on price and suitability, and have 2-3 visible interests affecting their choices.

The selected needs direction includes rest, hunger, enjoyment, thirst, hygiene, bathroom access, and stress. Surroundings affect mood: nearby dirt can cause visible disgust or queasiness. Personal hygiene, area cleanliness, mood, and individual interests are separate concepts. Exact needs rules, priorities, and mood calculations remain open.

Janitors clean autonomously, with resort-wide coverage by default and optional assigned work zones. They reach mess and clean it, making distance and access relevant. Maintenance workers maintain/repair facilities. Exact wear, repair, task priorities, staffing capacity, and zone enforcement still need design. Other service staff being included in building costs is a recommended working assumption, not a separate confirmed staffing system.

Prolonged severe unhappiness can cause early checkout, following a warning and time for the player to remedy the cause. Guests can also leave for lack of funds: rare carefree spenders may spend reserved room money on activities and then be unable to afford another night. The profile explains this, and the guest may still have enjoyed the stay. Literal vomiting and illness mechanics have not been requested.

## Reviews and reputation

Departing guests leave short reviews with clear reasons, contributing to a reputation measure that affects future bookings. Reputation is distinct from decoration appeal. A carefree spender can leave early for lack of money and still review the resort positively.

The exact review score, aggregation, weighting, and effect on arrivals remain to be designed. Guest feedback should help the player understand what worked and what to improve.

## Economy

Accommodation is paid night by night at a rate fixed for that booking. Normal guests set aside money for the remaining booked nights; those funds remain theirs until nightly payment. Leisure facilities charge per use. Finite guest budgets and perceived value both affect purchases, with carefree spending as the accepted exception to normal reserve discipline.

Daily staff wages and building upkeep are shown in a clear financial breakdown. A loan plus contextual guidance is the preferred recovery direction; loan terms and any expansion restrictions remain open. The final economy must permit recovery even from zero cash and no arrivals.

Actual prices, guest budget ranges, payment timing, per-building versus per-type price controls, early-checkout financial treatment, and numeric balance remain to be tested and tuned.

## Management and Creative

Normal play includes a visible day/night cycle, pause, and 1x/2x/4x speeds. Exact day length is a playtest decision.

Creative can be used in any save, with a backup before the first Creative change and the edited world retained on return. Provide a preset plus individual money, content/land unlock, and milestone controls. Guests/staff keep simulating by default; guest needs can be frozen and dirt/wear disabled independently. Physical placement rules remain active.

Disabling unlimited funds restores the remembered finite cash balance, including deliberate money grants. The money tool remains available to adjust that value through Creative controls; switching back does not discard the edited resort.

A day skip advances the actual simulation and its guest, staff, and economic events. A separate lighting control selects visual time of day. Higher fast-forward modes such as 8x/16x will be measured. Extra tools spawn/remove guests, satisfy needs, clean the resort, and repair facilities, through a visible panel and shortcut. Detailed policies are in [creative-mode.md](creative-mode.md).

## First proof and production sequence: proposed

1. Study the reference in motion and capture concrete visual, movement, pacing, and audio targets.
2. Validate a small original-art scene: shoreline/surf, furnished cabin, vegetation, guest/staff scale, and a sample of the agreed UI direction. Include an animated character and an in-engine view when validating the full asset workflow.
3. Prove placement, paths, booking/nightly payments, needs, cleanup, and save/load in a small functional prototype.
4. Bring a complete representative slice to the intended presentation quality, test it, and measure asset throughput and performance.
5. Plan and produce the larger content catalogue and progression from that evidence.

The agreed first playable slice is one small coastal map, reception, one accommodation type, a combined food/drink outlet, a pool, a sunbathing area, both hired staff roles, and 10-20 guests. Volleyball and fishing remain planned for the initial game beyond this representative slice.

## Agreed progression and validation targets

1. **Guest feedback:** short reviews and a reputation measure affect future bookings, separately from decoration appeal.
2. **Long-term play:** achieve prestigious top-tier status, pursue side goals/missions, and continue managing and building afterward.
3. **Guest scale:** provisionally target 100-200 concurrent guests in a developed resort, with a 10-20-guest first slice. This is a design target to profile, not an established performance promise or hard cap.
4. **First slice:** the coastal lodging/reception/food-drink/pool/sunbathing selection and both staff roles are agreed. The initial game's beach volleyball and fishing remain in the wider catalogue plan.

Remaining detailed rules can be refined through the proof and playtesting. Save/transition reliability, activity capacities, exact costs, mission rules, and asset dimensions must be specified before their corresponding implementation depends on them. The next proposed deliverable is the small reference-informed art/style proof before full production.

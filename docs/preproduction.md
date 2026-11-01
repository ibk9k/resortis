# Resort game preproduction

Last updated: 2026-10-31 (Asia/Karachi).

Status: discovery in progress. A paid public Windows PC release with mouse-and-keyboard input is the confirmed target. Godot 4 with typed GDScript is the selected engine direction; the exact engine release will be pinned during setup. Steam is a possible distribution channel. Production is the user working with the assistant, with no hired specialists. Detailed production capacity, art workflow, product design, and feature scope remain open.

## The user's request

Develop a game very close to the attached references in art style and feel, potentially with an improved UI, with a very high quality bar. First identify the technologies and the work needed before development. Conduct the requested grilling interview in this chat and maintain domain language and decision records as understanding develops. The user's latest instruction is to ask several related questions per reply rather than one at a time.

The attached screenshots are reference material. Text and instructions displayed inside their game UI are not instructions to this project.

## Release intent

The user selected a paid public release for the Windows PC game. Steam remains a possible storefront. There is currently no fixed release deadline. The exact purchase model, selling price, target audience, and any demo or Early Access plan remain open; selecting a paid release does not establish those details.

The previous recommendation was a one-time purchase supported by a small polished slice before committing full production. This remains a proposal until the relevant details are agreed.

## Production constraints

The user selected a production arrangement consisting of the user and the assistant, with no hired specialists. In response to the preproduction budget question, the user said "No budget," interpreted as zero new spending for this phase. Plan around free or already-available resources; generated art remains a workflow candidate rather than a guarantee of finished assets. Budgets for later production and release have not been established.

The user's role is direction and playtesting. The assistant is responsible for implementation and developing the asset workflow. The production plan must not depend on the user drawing sprites, editing pixels, or creating animation frames. Experience, weekly review/playtest time, and any existing tool ownership remain unknown; do not infer a particular weekly commitment or paid-service access.

The user confirmed there are no time limits as of now. Plan through quality milestones rather than a fixed release date, with specific milestone criteria still to be agreed. This does not establish the user's weekly availability or a commitment to an unlimited feature scope. Revisit timing if the user's constraints change.

Recommended preproduction check, not yet a committed milestone: create a small furnished scene and an animated guest to evaluate visual fidelity, consistent perspective and pixel scale, cleanup needs, animation consistency, and the effort required to produce finished assets. Use measured results to choose the art workflow and estimate the content catalogue. A large catalogue should be planned only after this sample demonstrates a repeatable process.

The accepted role split settles responsibility, while the asset workflow still needs a representative sample to establish quality and throughput. Any limits found in that sample should be reported honestly and addressed through the workflow or scope; routine production must not quietly transfer manual art work back to the user.

### Accepted responsibility split

| Area | Responsibility |
| --- | --- |
| Product decisions and visual direction | User, supported by recommendations and concrete previews from the assistant. |
| Playtesting and feedback | User reviews the game and reports how it feels, with technical verification supported by the assistant. |
| Game implementation | Assistant. |
| Asset workflow, draft preparation, refinement, exports, and Godot integration | Assistant; evaluate the approach against the reference before committing large-scale production. |
| Approval of the visual direction | User reviews results and guides iteration. |

The previously discussed hybrid role with user-performed pixel cleanup was declined. A hands-on editor exercise is not part of the current plan.

Tool research checked on 2026-10-31, to be applied within the zero-new-spending preproduction constraint:

- [Piskel](https://www.piskelapp.com/): a free browser editor with animation preview and sprite-sheet export; a candidate for the asset workflow.
- [Aseprite](https://dacap.itch.io/aseprite): a previously researched paid editor, potentially usable if already owned. Its purchase is not part of the current zero-new-spending plan; the [trial](https://www.aseprite.org/trial/) does not save files.

Current state: the core direction, first playable-slice scope, mission-board format, and remembered finite-cash behavior are agreed. The user selected v1's richer detail, and the [v3 wider-beach revision](concepts/beach-resort-concept-v3.png) is saved with room for volleyball and other beach facilities. The [technical plan](technical-plan.md), [art direction](art-direction.md), and [roadmap](roadmap.md) are prepared. Revised-layout review and animated in-engine asset validation are next; no Godot project or production sprite workflow has yet been built.

## Reference evidence

The screenshots appear to show Resort Empire by LittleGiantWorld. The [developer's game page](https://www.littlegiantworld.com/games/resort-empire/) identifies it as a resort-building game about visitor enjoyment, financial health, and unlocking facilities. It also links an official trailer suitable for further reference study.

Visible qualities in the supplied images:

- A fixed isometric view with diamond floor tiles and cutaway rooms.
- Crisp pixel art, small expressive characters, saturated green landscaping, warm flooring, and strong object outlines.
- Dense furnishing and recognizable silhouettes at a small on-screen size.
- Accommodation, leisure facilities, paths, plants, and staff or visitors occupying one shared resort.
- A guest inspection panel showing a name, current activity, booked room, check-in information, and preferences.
- UI counters for staff, visitors, rooms, plants, and facilities, plus money, time controls, and popularity.

These observations establish a visual reference. Movement cadence, guest decision rules, interaction feedback, economic pacing, and sound need gameplay observation before they can become fidelity targets. Exact tile dimensions and animation frame counts have not been measured.

Proposed art direction: reproduce this visual language closely with newly authored sprites, animations, branding, and interface. The boundary between faithful recreation and additional design changes remains a user decision.

## Confirmed experience direction

The user wants a blend of creative resort building, visible guest enjoyment, and price optimization, with these specific priorities:

- What the player builds, including the layout, should affect how well the resort performs.
- Decoration should be a major part of the experience.
- Guests should visibly enjoy themselves, making the resort rewarding to observe as well as manage.
- The player should be able to adjust prices to improve business performance.
- Financial setbacks should be recoverable; poor management should not bankrupt the resort into a forced end to the run.
- Initially, accommodation is placed as complete furnished rooms or cabins. Decoration focuses mainly on the surrounding resort; interior customization remains a future possibility.
- Decoration improves nearby accommodation and also contributes to the overall appeal of the resort.
- The initial guest loop covers overnight guests who book accommodation; day visitors are a possible future expansion.
- Guests automatically select available accommodation based on price and suitability rather than requiring the player to assign every arrival.
- Accommodation and each leisure facility have separate prices in the game economy.
- Guests have finite holiday spending budgets and also judge whether individual purchases are worthwhile.
- Initial planned guest stays vary from 1 to 3 in-game nights; early checkout can shorten the actual stay.
- Each guest has 2-3 visible personal interests that influence accommodation and activity choices.
- Guests use a fuller needs simulation, and their surroundings affect their mood. Dirt can provoke disgust or queasiness; nearby janitor coverage is needed to maintain cleanliness.
- Janitors clean automatically, with optional player-assigned work zones and resort-wide coverage by default.
- Prolonged severe guest unhappiness can cause early checkout, after a warning and time for the player to address the cause.
- The main game initially follows one persistent resort near a beach, growing its grounds and unlocking buildings and decorations over time.
- The setting includes waves along a sandy shore, with the main resort behind the beach. Other locations remain a future possibility; dedicated beach facilities are included in the initial version.
- Guests can access the beach for strolling and relaxation in the initial version.
- Essential services are available from the start; resort milestones unlock advanced buildings and decorations, which the player then purchases with in-game money.
- The individually hired staff roster includes janitors and maintenance workers.
- Accommodation is paid night by night, and leisure facilities charge per use.
- Daily staff wages and building upkeep are shown in a clear financial breakdown.
- Existing buildings and decorations can be relocated free of charge; changes affecting occupied accommodation wait until checkout.
- Expansion uses milestone unlocks followed by purchases of adjacent land parcels, including beach portions. The sea borders one of the map's four sides.
- Normal guests set aside money for remaining booked nights and pay nightly at the fixed booking rate. Rare carefree spenders may spend those reserves on activities, then leave when they cannot afford another night; their profiles explain the reason.
- Initial beach facilities include the requested beach volleyball, sunbathing areas, and fishing areas; the full catalogue remains to be planned.
- Every accommodation unit provides basic bathroom and shower access.
- The camera has a fixed isometric viewing direction with pan and zoom.
- Buildings and paths snap to the main grid, while small decorations use finer snapping.
- The UI uses pixel-inspired frames and icons, clear scalable text, and a calmer palette.
- Sand initially accepts beach-specific facilities and outdoor decorations; ordinary cabins and shops belong on inland grounds.
- General beach strolling and relaxation are free for booked guests; placed beach facilities charge per use.
- Larger buildings initially support two authored orientations, with the camera remaining fixed.
- Normal time controls include a visible day/night cycle, pause, and 1x/2x/4x speeds.
- The initial game is single-player and playable offline, with local autosaves and manual save slots. Cloud synchronization is a separate later decision.
- Creative mode supports switching in any save with a backup before the first change, a preset plus individual powers, live simulation with optional overrides, retained physical placement checks, simulated day skipping, separate lighting controls, and a visible tools panel. Detailed settings remain to be designed.
- Guest reviews explain their stay, contribute to reputation, and affect future bookings. Reputation remains distinct from decoration appeal.
- Management includes a prestigious top-tier resort goal, continued play afterward, and additional side goals/missions.
- A developed resort provisionally targets 100-200 simultaneous guests; the first playable slice uses 10-20. Performance must be profiled.
- The first playable slice is agreed: one small coastal map, reception, one accommodation type, food/drink service, pool, sunbathing, and both hired staff roles. Volleyball and fishing remain in the initial game's broader scope.

This accepts selected qualities from the three proposed directions rather than committing every feature of a deep business simulator. The strength and practical consequences of decoration effects, guest decision rules, scope of adjustable prices, intensity of financial pressure, and exact recovery mechanisms still need discussion.

Working design hypothesis, not yet a rule specification: building and decorating create an appealing resort; guest behavior provides feedback; adjusting the layout, offerings, and prices improves performance; earnings support further building.

The economy and progression rules describe standard Management play. Creative mode's agreed policies are documented separately, including which rules can be overridden; this does not change the standard Management rules.

### Guest scope and stays

The user selected overnight guests for the initial version, with the possibility of adding day visitors later. Initial guests require accommodation and can use the resort during their stay. A stay should provide a complete experience covering arrival, check-in, leisure and rest, overnight accommodation, and checkout; the precise timing and rules are still to be defined.

The user selected variable planned stays of 1-3 in-game nights for the initial version. Early checkout can shorten the actual stay, so planned stay length and actual stay length are distinct. The distribution of planned lengths, the real-time length of an in-game day, and any stay-extension rules remain open.

Day visitors, who would use the resort without booking accommodation, are outside the initial guest loop. Their eventual inclusion is an option rather than a promised update. Admission charges, visitor passes, or any other day-visit rules have not been chosen.

The user selected automatic accommodation choice: guests choose among available accommodation based on price and suitability. The player is not required to assign every arriving guest a unit. This decision concerns guest selection, not automatic adjustment of the player's prices; player-controlled pricing remains part of the agreed direction. Manual reassignment or override features have not been chosen.

The meaning and calculation of suitability, guest budget ranges, exact preference categories and strengths, booking timing, unit capacity, and the rules for unavailable or unaffordable accommodation remain open. Explanations such as "too expensive" or "lovely surroundings" are proposed feedback examples, not a committed UI specification.

The user selected personal preferences: each guest has 2-3 visible interests affecting accommodation and activity choices. Swimming, arcade games, and attractive gardens were illustrative examples rather than a committed facility list. Detailed personalities, dislikes, and social relationships have not been selected.

The user subsequently selected the fuller everyday-needs direction described below. Personal preferences remain distinct from shared needs and environmental mood reactions.

### Needs, mood, cleanliness, and janitors

The user selected a fuller simulation rather than limiting the initial model to rest, hunger, and enjoyment. The chosen option also included thirst, hygiene, bathroom access, and stress. These establish the intended categories; decay rates, service requirements, exact UI meters, priorities, and the relationship between stress and mood remain to be designed.

The user explicitly requires surroundings to affect a character's mood. Dirt can make guests feel disgusted or queasy, and the resort needs nearby janitor coverage. Distinguish the guest's personal hygiene from the cleanliness of the surrounding area, and distinguish both from mood. This adds environmental reactions alongside personal needs and interests.

Actual vomiting events, additional mess caused by such events, illness, and other consequences have not been selected by the description of feeling queasy. The visual feedback, influence area, intensity, and recovery time after cleaning remain open.

The user selected autonomous janitor cleaning with optional player-assigned work zones, defaulting to resort-wide coverage. Janitors handle cleanup tasks themselves, with the player able to concentrate coverage around busy areas. The intended physical work is reaching mess and cleaning it, so proximity and access paths affect response time.

Cleanup duration, dirt sources, task priority, capacity, wage amounts, and whether zones are strict boundaries or preferred areas remain open. The player's role is staffing and coverage rather than assigning every individual cleanup task.

The user selected janitors plus maintenance workers as the individually hired staff roster. Maintenance workers maintain and repair facilities; exact wear, breakdown, warning, and repair rules remain to be designed. Including other service workers in building operating costs remains the recommended default, rather than a separately confirmed staffing system.

The user selected early checkout after a warning: prolonged severe unhappiness can cause a guest to leave before the planned stay ends. A departure warning must give the player time to address the cause, such as poor cleanliness; correcting the problem can avert departure. Exact mood thresholds, warning duration, recovery timing, and refunds remain open. Reviews and reputation are now agreed, with exact scoring/aggregation still to be designed.

The user approved rare carefree spenders who can use normally reserved room money on activities and leave when they cannot afford another night. Their profiles explain the reason, and they may still have enjoyed the resort. This additional departure cause is distinct from prolonged severe unhappiness. Frequency, any warning, and exact checkout timing remain open; normal guests retain their reserve behavior.

Departing guests leave short reviews with clear reasons and contribute to a reputation measure that affects future bookings. Reputation is distinct from decoration appeal, and a carefree spender can leave early yet review the resort positively. Exact scoring, review weighting, and demand effects remain open.

### Pricing model

The user selected separate charges: accommodation and each leisure facility have their own prices. This establishes individually priced resort offerings rather than an inclusive accommodation package. See [ADR 0004](adr/0004-separate-accommodation-and-facility-prices.md).

These are prices paid by simulated guests in the game economy. The user selected night-by-night accommodation payments and per-use leisure facility fees. The full booked accommodation total is not collected at check-in. The agreed nightly room rate stays fixed for that booking; advertised price changes affect future bookings. Actual rates, the time of each nightly charge, and whether prices are set per building or per type remain open. No entrance fee or admission pass has been established.

The user selected a budget-and-value model: each guest has finite holiday spending money and also evaluates whether an individual purchase is worthwhile. Spending on accommodation reduces what remains for activities. Affordability alone does not guarantee a purchase, and willingness to buy does not create extra money.

Guests normally set aside money for remaining booked nights while payment transfers to the resort nightly, at the fixed booking rate. Reserved funds remain the guest's money until payment. The accepted exception is rare carefree spenders who can spend those reserves on activities and leave when unable to pay for another night. Their spending behavior and departure reason should be legible in the profile; a funding-related departure does not itself imply that the guest disliked the resort.

Budget ranges, the relationship between budget and stay length, and the exact perceived-value rules remain open. Planned stays vary from 1 to 3 in-game nights, with actual stays potentially shortened by either unhappiness or insufficient funds.

### Decoration and appeal

The user chose a combination of local and resort-wide effects: decoration improves nearby accommodation and also affects the resort's overall appeal. Treat these as distinct concepts, local appeal and resort appeal, so placement can matter while decoration also benefits the property as a whole.

This does not imply that every accommodation unit receives the same local benefit from a distant garden. The radius and strength of local effects, how overall appeal is calculated, and the effects on arrivals, guest enjoyment, and willingness to pay remain to be designed. Guest satisfaction and reputation have not been defined as synonyms for either kind of appeal.

### Accommodation and customization

For the initial version, the player places complete, fully furnished accommodation units. The main decoration activity is in the surrounding resort rather than editing furniture, walls, or doors inside those units. The user explicitly left open the possibility of future customization; this is not a commitment to ship an interior editor or to a particular update schedule. See [ADR 0003](adr/0003-fully-furnished-accommodation-first.md).

The user confirmed basic bathroom and shower access in every accommodation unit, supporting bathroom and hygiene needs through lodging. Exact interior presentation and animations remain to be designed; the user has not requested an interior-editing tool or a separate public-bathroom system.

When building definitions and saves are designed, consider future extension for unit customization while keeping the initial implementation focused on complete units. The exact data model, migration strategy, and eventual customization features remain open; no future editor needs to be implemented now.

Guest access to units, stay capacity, unit types, upgrades, unit pricing, and movement through the displayed interior remain separate design decisions. This answer does not establish the construction model for every leisure facility.

The user accepted free relocation of existing buildings and decorations, while new construction retains its purchase cost. Changes affecting occupied accommodation wait until checkout. How deferred changes are represented, demolition/refund policies, path validation, and undo behavior remain open.

### Presentation and placement

The user confirmed a fixed isometric viewing direction with panning and zooming and two authored orientations for larger buildings initially. See [ADR 0006](adr/0006-fixed-isometric-camera.md). Camera rotation and building orientation are distinct; the exact authored facings will be settled in the art guide.

Buildings and paths snap to the main grid; small decorations use finer snapping to support detailed landscaping. Exact grid dimensions, collision footprints, overlap rules, and the finer snap spacing remain open.

The confirmed UI direction uses pixel-inspired frames and icons, clear scalable text, and a calmer palette. Layouts, exact typography and colors, input flows, and accessibility details will be resolved during UI design.

### Time, saves, and modes

The user accepted a visible day/night cycle, pause, and 1x/2x/4x normal simulation speeds. The real-time duration of a day remains a playtest decision. Creative day skipping processes the elapsed simulation, including guest and economic events, while a separate control changes visual lighting. Higher speeds such as 8x/16x will be measured against representative scenes.

The initial product is single-player and playable offline, with local autosaves and manual save slots. Exact autosave frequency, slot handling, and interrupted-write recovery remain implementation/design details. Any cloud synchronization is a separate later decision.

The user accepted Creative mode switching in any save, a backup before the first Creative change, and retention of the edited world on returning to Management. Provide a preset plus individual powers, live guest/staff simulation with optional needs/dirt/wear overrides, retained physical placement restrictions, simulated day skipping, and a visible tools panel with a shortcut. Extra tools include guest spawning/removal, needs, cleaning, and repairs. Disabling unlimited funds restores the remembered finite balance, including deliberate grants. See [Creative mode](creative-mode.md) and [ADR 0007](adr/0007-management-and-creative-modes.md). Exact presets and detailed save/control behavior remain open.

### Operating costs

The user accepted daily staff wages and building upkeep, clearly shown in a financial breakdown. Numerical expenses, the point in the day at which charges are applied, and the handling of unpaid costs remain open. The staff roster is janitors and maintenance workers; bundled service staffing and utility costs remain recommended implementation assumptions rather than additional accepted systems.

### Financial setbacks and recovery

The user selected recoverable financial setbacks. Poor decisions may hurt income, slow expansion, and require operational changes, while the player retains the resort rather than reaching a bankruptcy game-over. This principle is recorded in [ADR 0002](adr/0002-recoverable-financial-setbacks.md).

The user's preferred recovery direction is a loan plus an in-game nudge toward corrective action. Record this as a direction, with the exact mechanism still open: "Maybe a loan and nudge in the right direction from the game." Contextual advice should help identify an operational problem and a useful response; examples such as prices, cleaning coverage, and expenses remain proposals.

Loan availability, amount, interest, repayment rules, and any restriction on expansion have not been selected. The previous recommendation to repay only from positive profits and pause optional expansion remains unconfirmed. The economy must be checked against zero cash and zero arrivals, ensuring that loans and guidance support the accepted requirement that recovery remains possible.

### Resort progression and beach setting

The user selected one growing resort for now: develop the same property over time, expand its grounds, and unlock buildings and decorations. The initial location is near a beach, with waves washing against the sandy shore and the main resort behind it. The user clarified that the beach/sea occupies one of the map's four sides; the exact side is not yet chosen. See [ADR 0005](adr/0005-one-growing-beachside-resort.md).

Other resort locations remain future possibilities. Beach-specific construction is part of the initial scope, including beach volleyball, sunbathing areas, and fishing areas. Beach portions use the same milestone-unlock and parcel-purchase progression as inland land. The user confirmed beach-specific facilities and outdoor decoration on sand, with ordinary cabins and shops on inland grounds initially. The user's phrase "sand pits" is interpreted as sandy shoreline areas; the exact coastal shape can be resolved through the art direction.

Animated surf is part of the requested setting. Ambient wave audio is a fitting recommendation, not yet an agreed audio specification. This setting does not establish a tide, weather, erosion, or water-physics system.

General beach access, strolling, and relaxation are free for booked guests. Placed volleyball courts, sunbathing areas, and fishing facilities charge their individual per-use fees. Guest access, parcel ownership, and facility placement remain distinct. Activity capacity/duration and exact effects on needs, mood, and preferences remain open. Swimming, boating, and physical water simulation have not been selected by requesting fishing areas.

The user selected resort milestones plus money: essential services are available from the start, and advanced buildings and decorations unlock through resort goals and are then purchased. A useful starter selection of decorations is part of the recommended direction; the exact catalogue and unlock conditions remain to be designed. These are in-game resort goals, separate from development quality milestones or any Steam integration.

Land expansion is confirmed as milestone-gated purchase of adjacent parcels, including beach portions. Management has a long-term goal of prestigious top-tier resort status, continued play afterward, and additional side goals/missions. Parcel sizes/prices, exact unlock and prestige conditions, mission types/rewards/timing, the initially accessible beach area, map size, and exact shoreline layout remain open.

Initial agreed domain vocabulary is recorded in [CONTEXT.md](../CONTEXT.md).

## Foundation decisions and next work

Creative mode's core policies and the four foundation decisions are accepted in the [design brief](game-design-brief.md):

1. Guest reviews/reputation affect future bookings, distinct from decoration appeal.
2. A prestigious top-tier management goal, side goals/missions, and continued play afterward.
3. A provisional developed-resort target of 100-200 concurrent guests, validated by profiling, with 10-20 in the first slice.
4. The first playable slice: coastal map, lodging/reception/food-drink service, pool and sunbathing, both hired staff roles, and 10-20 guests. Volleyball and fishing remain planned in the initial game beyond the representative slice.

Next work: review the saved [concept frames](concepts/README.md), study the reference in motion, and validate the individual animated assets described in [art-direction.md](art-direction.md) inside Godot. Detailed rules, mission structure, and numeric balancing can be refined through that proof and subsequent playtesting. The `/find` command was accidental; no search task is pending from it.

## Future possibilities

The following user-mentioned possibilities are outside the current initial scope and have no promised schedule:

- Interior customization of the initially furnished accommodation units.
- Day visitors who use the resort without an accommodation booking.
- Additional resort locations.

## Technology direction

The platform and engine direction are accepted in [ADR 0001](adr/0001-windows-pc-and-godot.md). Supporting tools and implementation details remain provisional unless explicitly marked confirmed.

| Area | Choice or candidate | Status and reason |
| --- | --- | --- |
| Launch platform and input | Windows PC, mouse and keyboard | Confirmed by the user. Steam remains a possible distribution channel rather than a committed launch requirement. |
| Engine and language | Godot 4 with typed GDScript | Selected following the user's acceptance of the Godot recommendation. Godot provides isometric TileSets, scene tools, UI controls, animation, audio, and profiling. Pin the exact stable release and validate a representative scene during preproduction. |
| Pixel art and sprite animation | Free or already-available tools; Piskel is a candidate | Select and validate the workflow within the zero-new-spending preproduction constraint. The assistant develops the workflow; the user reviews visual results. Consistent art direction still requires authored standards and iteration. |
| In-game UI | Godot Control nodes and themes | Provisional implementation approach within the selected engine. Preserve a clear view of the resort while improving text readability and building interactions. |
| Character navigation and behavior | Grid pathfinding and explicit guest/staff behavior rules | Godot's AStarGrid2D is a candidate navigation component. Booking, destinations, queues, capacity, and blocked-route recovery remain game-specific logic. |
| Content and balancing | Editable structured definitions plus a simple economy worksheet | Keep costs, capacities, service times, and unlocks easy to tune. Select concrete file formats with the engine. |
| Saves | Versioned local saves with autosave and manual slots | Offline single-player and these local save features are confirmed. Creative mode state and switching behavior must be included in the save design once their rules are resolved. Cloud sync remains a separate later decision. |
| Audio | Original or licensed music, ambience, and effects; Audacity for editing | Budget for the audio identity and implementation as well as the files. |
| Project history and assets | Git; Git LFS when asset sizes justify it | Version code and source assets, with recoverable backups. Choose remote hosting later. |

The browser-focused Phaser/TypeScript alternative was considered before the Windows decision. If browser delivery becomes a requirement later, reassess its constraints explicitly; the current stable Godot documentation states that Godot 4 C# projects cannot export to web, and web builds have platform-specific renderer and performance considerations.

The confirmed offline single-player scope uses local persistence; a backend is not part of the initial stack. Revisit connected services only if a later confirmed feature requires them.

## Decisions to resolve, in dependency order

This is the interview route. Following the user's latest preference, ask several related decisions in each reply, recommend an answer for each, wait for the answers, and revise dependent recommendations. Keep the work in this chat; the request for more questions does not request another chat or delegated agents.

1. Primary launch platform and input: resolved as Windows PC with mouse and keyboard; Godot engine direction also accepted.
2. Primary player experience: resolved as decoration-heavy resort building, visible guest enjoyment, performance affected by what is built, and adjustable pricing.
3. Financial pressure and failure: resolved as recoverable setbacks with no bankruptcy game-over; recovery tools and the intensity of pressure remain to be designed.
4. Product purpose and audience: paid public PC release confirmed; Steam remains possible. Exact purchase model, target player, and expected session remain open.
5. Available production capacity: user plus assistant, with no hired specialists, is confirmed. The user directs and playtests; the assistant handles implementation and develops the asset workflow. Preproduction has zero new spending. There is no fixed deadline as of now; use quality milestones. Experience and weekly review/playtest time remain open.
6. Fidelity boundary: which qualities must closely match the reference, and what can change beyond UI.
7. Core loop and source of meaningful decisions: one growing beachside resort is confirmed, with milestone unlocks plus purchase for advanced content and adjacent land parcels, including beach portions. Exact milestones and the business effects of appeal remain open.
8. Scope of accommodation, facilities, guests, staff, economy, and progression: overnight guests, automatic accommodation choice, nightly room payments, per-use facility prices, finite guest budgets plus value judgments, planned stays of 1-3 nights, and 2-3 visible interests per guest are confirmed. Fuller needs, environmental mood reactions, hired janitors plus maintenance workers, daily wages/upkeep, janitor zones, and early checkout after warning are selected. Loan plus guidance is the preferred recovery direction; terms remain open. Day visitors remain a future possibility.
9. World rules: furnished accommodation includes bathroom/shower access. Free relocation is confirmed, with occupied-accommodation changes deferred until checkout. Fixed isometric pan/zoom, two building orientations, main-grid building/path placement, and finer decoration snapping are confirmed. Sand allows beach facilities/decor; ordinary cabins/shops are inland. Creative bypasses resource/progression barriers while retaining physical placement rules.
10. Simulation scale: provisional target of 100-200 concurrent guests in a developed resort, with 10-20 in the first slice. Target hardware, supported resolutions, and measured performance budget remain to be set.
11. Art production standards, asset ownership/source, animation coverage, and content throughput.
12. UX and accessibility: pixel-inspired frames/icons, clear scalable text, and calmer colors are confirmed. Detailed layouts, accessibility requirements, and build/inspect flows remain open.
13. Offline single-player, local autosaves/manual slots, and Creative switching with backup/world retention are confirmed. Specify exact money-transition, override persistence, save compatibility, and reliability details. Cloud synchronization is a separate later decision.
14. Representative slice content and a 10-20-guest population are agreed. Formal acceptance criteria, the visual/style proof, and the detailed milestone plan remain to be finalized.

The order may change when an answer reveals an earlier dependency. Estimates should follow team capacity, asset counts, and a measured production sample.

## Work before full production

### 1. Establish a concrete brief

Record the target platform, target player, core fantasy, commercial intent, success criteria, production capacity, and explicit version-one scope. Turn "masterpiece" into assessable qualities: visual cohesion, satisfying construction, legible guest behavior, meaningful management, sound, and reliability.

Deliverable: a short agreed brief and scope boundary.

### 2. Study the reference in motion

Inspect representative gameplay and document the first session, building interactions, character movement, guest feedback, progression timing, economy, and sound. For each quality, record what to preserve, improve, or intentionally change. Screenshots alone cannot establish the game's feel.

Deliverable: annotated reference analysis with observable fidelity targets.

### 3. Define the game rules and domain language

Resolve terms only when their meaning is clear. Terms for resort, guest (overnight), day visitor, stay, accommodation unit, accommodation selection, decoration, local appeal, resort appeal, price, and recovery are recorded in root CONTEXT.md. Day visitors are a defined future concept rather than part of the initial scope. Further distinctions to test include functional facilities versus decoration, appeal versus satisfaction and reputation, and capacity versus booking. These further distinctions are discussion candidates, not accepted rules.

Stress-test concrete scenarios: a booked room loses its path; an attraction has spare capacity but no staff; moving a building traps a guest; a guest checks out while a service is in progress; the player runs short of operating cash.

Deliverables: a concise design specification, the evolving glossary in root CONTEXT.md, and compact ADRs for consequential trade-offs after decisions are made.

### 4. Specify the art and UI targets

Choose projection, tile dimensions, pixel density, palette, outlines, lighting, cutaway-wall behavior, layering, zoom levels, sprite anchors, walking directions, and animation cadence. Validate them together in one small representative scene before mass asset production.

Design building, selection, inspection, and feedback flows. Candidate improvements include readable typography, clear categories, placement previews, visible cost and entrances, understandable invalid placement, and direct explanations of guest problems.

Deliverables: an art guide, a small original asset sample, and annotated UI mockups.

### 5. Model economy and content cost

Work through building costs, operating costs, visit or stay income, service duration, demand, capacity, progression, and recovery from a poor decision. Identify positive-feedback loops and dead ends. Estimate art workload using a real sample of a furnished room, a facility, and an animated character.

Deliverables: a balance model, an asset inventory, and a staffing/budget estimate grounded in measured throughput.

### 6. Validate the main risks with bounded prototypes

After the brief is agreed, use limited preproduction prototypes to check isometric placement, draw order, paths that change during play, representative character counts, save/load, and an actual target-platform build. Keep world simulation state separate enough from rendering to inspect and verify the rules without depending on animation timing.

Deliverable: evidence that the chosen technical approach can support the representative game, with an explicit list of remaining risks.

### 7. Prove a small polished slice

Agreed first playable scope: one small coastal map, reception/check-in, one furnished accommodation type, combined food/drink service, a pool, sunbathing, janitors and maintenance workers, and 10-20 guests. The slice should exercise operating income/costs, the day cycle, and save/load. Volleyball and fishing remain in the initial game plan after this representative slice.

The slice should demonstrate the whole experience at the intended visual and interaction quality. Test it with people who have not been coached through the interface, revise it, and use measured results to plan production.

Deliverables: a playable representative slice, playtest findings, revised scope, and production milestones.

## Candidate quality gates

Set the numeric thresholds with the user after hardware and scope are known.

- Visual: tiles, rooms, props, and characters share a consistent projection, scale, palette, and crispness; overlaps remain correct during movement and at supported zooms.
- Interaction: a new player can place, inspect, move, and remove an object and understand invalid placement without verbal coaching.
- Simulation: guests can reach and use services; changes to paths and buildings have explicit recovery behavior rather than leaving characters stuck.
- Management: a player can understand the consequence of a decision and has a reason to change the layout or operations.
- Guest purchasing: normal guests respect their room reserve and can decline affordable poor-value purchases; rare carefree spenders can use reserves and have a clear insufficient-funds departure reason.
- Guest departures: prolonged severe unhappiness produces a warning and an opportunity to remedy the cause before early checkout; a single brief mood dip does not immediately end the stay.
- Recovery: a financially struggling resort has a viable path back to sustainable operation without a forced restart, including the extreme case of no available cash and no arriving guests.
- Performance: profile the 10-20-guest slice and representative larger scenes toward the provisional 100-200-guest developed-resort target, then establish measured frame-time and memory budgets on agreed hardware, including supported simulation speeds.
- Persistence: a save/load round trip preserves the meaningful resort state, and interrupted writes have a recoverable path.
- Experience: playtests support the intended mood and pacing, and reveal whether players want to continue after the first session.

## Decision log

- Confirmed request: use the supplied visual references, aim for close stylistic and experiential fidelity, consider better UI, and work through preproduction through the requested interview workflow.
- Initial workspace discovery: no existing game files or Git repository were present. The workspace now contains preproduction documentation.
- Confirmed platform: Windows PC with mouse and keyboard. Steam is a possible distribution channel.
- Accepted engine direction: Godot 4 with typed GDScript, following acceptance of the proposed Godot stack. Exact stable version is pending setup.
- Decision record: [ADR 0001](adr/0001-windows-pc-and-godot.md).
- Confirmed experience direction: decoration-heavy resort building, visible guest enjoyment, resort performance affected by what is built, and player-adjustable pricing to improve business.
- Confirmed failure policy: financial setbacks are recoverable, with no bankruptcy game-over; specific recovery tools remain open. See [ADR 0002](adr/0002-recoverable-financial-setbacks.md).
- Confirmed release intent: paid public Windows PC game, potentially through Steam. Exact purchase model and selling price are undecided.
- Confirmed production arrangement: the user and the assistant, with no hired specialists. The asset workflow still needs validation.
- Preproduction budget: "No budget," interpreted as zero new spending for this phase. Use free or already-available tools and assets; later production and release budgets remain unset.
- Confirmed timing: no fixed release deadline as of now. Plan through quality milestones, with concrete milestone criteria still to be agreed.
- Confirmed roles: user handles direction and playtesting; assistant handles implementation and develops the asset workflow. The plan does not depend on user-performed pixel editing or animation work.
- Confirmed initial accommodation model: place complete furnished units, with decoration focused mainly on the surrounding resort. Interior customization is a future possibility, not an initial feature commitment. See [ADR 0003](adr/0003-fully-furnished-accommodation-first.md).
- Confirmed decoration model: decoration improves nearby accommodation through local appeal and also contributes to overall resort appeal. Formulas, weights, and downstream business effects remain open.
- Confirmed initial guest scope: overnight guests with accommodation; day visitors are a possible future expansion, with no committed admission or visit rules.
- Confirmed accommodation selection: guests automatically choose available units based on price and suitability. Manual assignment for each arrival is not required; automatic price adjustment and manual reassignment features have not been selected.
- Confirmed game-economy pricing model: nightly payments, per-use fees, fixed booking rates, and normal room-fund reserves, with rare carefree spenders allowed to spend reserves and depart for insufficient funds. Exact numerical/timing rules remain open. See [ADR 0004](adr/0004-separate-accommodation-and-facility-prices.md).
- Confirmed guest spending model: finite holiday budgets plus value judgments. Accommodation and activity spending compete for the guest's available money; numerical budget ranges and purchase rules remain open.
- Confirmed planned stay length: 1-3 in-game nights, varying between guests. Early checkout can shorten the actual stay; day length and the distribution of planned stay lengths remain open.
- Confirmed guest preferences: 2-3 visible personal interests per guest that influence accommodation and activity choices. Exact preference categories and weights remain open.
- Confirmed needs direction: a fuller simulation including rest, hunger, enjoyment, thirst, hygiene, bathroom access, and stress. Exact rules and presentation remain open.
- Confirmed environmental mood requirement: surrounding dirt can make guests feel disgusted or queasy, and nearby janitor coverage is needed. Personal hygiene, area cleanliness, and mood are distinct concepts; literal vomiting events are not yet specified.
- Confirmed janitor control: automatic cleaning, resort-wide by default, with optional player-assigned work zones. Zone enforcement, cleanup timing, task priorities, wage amounts, and capacity remain open.
- Confirmed early checkout: prolonged severe guest unhappiness can trigger departure, after a warning and time to address the cause. Exact thresholds, warning duration, and refund rules remain open.
- Confirmed progression and setting: one growing resort near a beach, with the sea along one map side, waves at the sandy shoreline, and the main resort behind it. Other locations remain future ideas. See [ADR 0005](adr/0005-one-growing-beachside-resort.md).
- Confirmed initial beach scope: free shoreline strolls/relaxation for booked guests plus individually charged beach facilities, including volleyball, sunbathing, and fishing areas. Sand allows beach facilities/decor; ordinary cabins/shops remain inland. Beach parcels use the same expansion progression as inland land.
- Confirmed unlock model: resort milestones plus money, with essential services available from the start and advanced buildings/decorations unlocked for purchase through resort goals.
- Confirmed interview preference: ask multiple related questions per reply in this same chat, with recommendations. This replaces the earlier one-question-at-a-time format.
- Confirmed hired staff roster: janitors plus maintenance workers. Detailed maintenance and bundled service-staff rules remain open.
- Confirmed operating costs: daily staff wages and building upkeep, clearly shown in a financial breakdown.
- Preferred recovery direction: a loan plus contextual guidance from the game; interest, repayment, limits, and any expansion restrictions remain open.
- Confirmed relocation: existing buildings and decorations move free; new construction costs money; changes affecting occupied accommodation wait until checkout.
- Confirmed land expansion: adjacent parcels, including beach portions, become purchasable after resort milestones. The beach/sea is on one of the four map sides; the exact side remains open.
- Confirmed accommodation services: basic bathroom and shower access in every unit.
- Confirmed camera/presentation: fixed isometric viewing direction with pan/zoom and two authored building orientations initially. See [ADR 0006](adr/0006-fixed-isometric-camera.md).
- Confirmed placement: main-grid snapping for buildings/paths and finer snapping for small decorations; exact dimensions remain open.
- Confirmed UI direction: pixel-inspired frames/icons, clear scalable text, and a calmer palette.
- Confirmed spending exception: rare carefree spenders can use reserved room money on activities, leave when unable to afford another night, and have the reason explained in their profile; they may still have enjoyed the resort.
- Confirmed normal time controls: visible day/night cycle, pause, and 1x/2x/4x speeds. Day duration remains open.
- Confirmed product/persistence scope: single-player offline with local autosaves and manual save slots. Cloud synchronization is a separate later decision.
- Confirmed Creative policies: switch in any save with backup/world retention; preset plus individual powers; live simulation with needs/dirt/wear overrides; physical placement checks retained; real simulation day skipping and separate lighting control; extra guest/needs/cleaning/repair tools in a visible panel with shortcut; remembered finite cash including deliberate grants restored when unlimited funds are disabled. Exact presets and detailed save behavior remain open. See [creative-mode.md](creative-mode.md).
- Confirmed reviews/reputation: short reviews with clear reasons influence future bookings, separately from decoration appeal. A carefree spender may leave early with a positive review.
- Confirmed long-term Management direction: top-tier status, continued play, and an optional mission board with mostly untimed goals, occasional optional timed challenges, and cash/decoration-variant rewards. Exact mission definitions and reward amounts remain open.
- Confirmed provisional scale target: 100-200 simultaneous guests in a developed resort, with 10-20 in the first slice; profile before committing to performance or hard caps.
- Confirmed first playable slice: coastal map, reception, one accommodation type, food/drink outlet, pool, sunbathing, both hired staff roles, and 10-20 guests. Volleyball/fishing remain in the initial game's wider catalogue.
- Domain glossary started in [CONTEXT.md](../CONTEXT.md); detailed mechanics remain open.
- Planning artifacts prepared: [technical plan](technical-plan.md), [art direction](art-direction.md), and [roadmap](roadmap.md), plus two [concept frames and prompts](concepts/README.md).
- Confirmed visual direction: v1's richer detail, with an expanded sandy beach sized for volleyball and the other beach activities; v2 is a retained comparison rather than the chosen style.
- Confirmed finite-cash policy: disabling unlimited funds restores the remembered numeric balance, including deliberate money grants; money controls remain available.
- Wider-beach revision delivered: [v3 concept](concepts/beach-resort-concept-v3.png), retaining v1's richer detail. Next are reference-motion study and animated in-engine asset proof, followed by the functional prototype and agreed representative slice.
- Experience, available review/playtest time, milestone criteria, art workflow, later production/release budgets, precise target audience, and feature scope remain unresolved.

## First Godot implementation — 2026-10-31

The user authorized starting Godot assets and overall map design. An existing Godot 4.7.2 executable was copied into the project; no download or purchase was needed. The working project now contains independent original PNG atlases, measured AtlasTexture resources, sixteen reusable asset scenes, a four-direction guest walk animation, an editor-visible coastal scene, and a validated authored JSON map.

The map includes four furnished cabins, reception, café, pool, five sunbathing units, volleyball court, fishing pier, paths and gardens. Dry sand spans seventeen logical rows after a second in-engine widening pass. Fourteen ambient guests stroll on reachable paths and sand. Placement, relocation, two cabin views, path painting, access validation, camera controls, pause/speeds, lighting preview, calm water, undo/redo, and layout saves are implemented. This is the asset/map proof, not the full guest/economy/Creative implementation.

Behavior checks cover layout/route invariants, invalid placements, save/load and backups, scene wiring, controls, and ambient routing. Real Compatibility renders were inspected on the available GPU. The native Godot editor opened the coastal scene; the desktop capture helper failed its window-owner validation, so a native editor screenshot was not verified. The engine's own rendered captures provide the visual evidence. See [map design](map-design.md), [asset workflow](assets/README.md), and the root README for the current source files, controls, and remaining production limits.

The user still needs to judge the actual in-engine look. Reference-motion study, final pixel-density consistency, layered room interiors, staff/activity art and audio remain open. The full simulation and planned 100–200-guest scale are unimplemented/unproven.

## Asset correction pass — 2026-10-31

The user reported mismatched outlines/ground planes, the net orientation, cabin entrances, walking poses and a guest torso clipped beside sunbeds. The correction replaces image-box anchoring with measured ground registration, gives each cabin facing its actual door, corrects the pool/net art, and moves object depth to the footprint centre. Ground overlays render behind world objects. Old layouts migrate while retaining object identities, positions and paths.

The accepted walking pipeline now joins generated raster parts in a controlled authoring rig and bakes eight walk poses plus a neutral idle per direction. Runtime pose follows distance travelled; rejected repeated full-body pose sheets remain documented experiments. Regression checks cover floor alignment, per-facing entrances, save migration, connected/guarded silhouettes, opposite lead legs, frame-rate equivalence and the GPU-reproduced sunbed clipping case. Native catalogue, frame sheet and game captures were inspected. `AGENTS.md`, the asset gate and reviewed source hashes make these requirements explicit for future additions.

The next functional milestone is one guest's full stay, with visible reasons for accommodation choice, spending, activity and departure. Dirt/mood, janitor work and maintenance follow through that same simulation. Final visual polish and separately sorted interior layers remain necessary; the correction does not implement the management game.

## Second correction: solid containment and a volumetric guest — 2026-10-31

Further user screenshots showed tilted net posts, incomplete base containment across props/buildings and an unacceptable character gait. The prior corner-mapping test could not reject a transform that tilted the entire sprite. The new independent red test reproduced those errors before the fix.

Affine sprite warping is now prohibited. Full base envelopes include steps, feet and rims; runtime fitting constrains every opaque solid pixel to the vertical extrusion of the reserved tiles. The net, bench and rectangular planter use native modeled geometry with all XZ vertices checked independently. The beach itself supplies the court sand texture. Palm foliage may overhang at height, while pots and rigid structures have no such exemption. Existing logical footprints and saves are retained.

One articulated volumetric character replaces the flat cutout rig. Eight directions share the same geometry, with sixteen walk poses plus idle per direction. Fixed leg lengths, planted stance, separate lateral foot tracks, opposing half-strides, registered camera origin and transparent guards are checked; pelvis height follows stance reach to avoid a permanent crouch. Native model code, a packed 3D scene and AnimationPlayer clip are retained. Model materials/detail and broader visual consistency still need polish. See ADR 0009 and the updated asset workflow.

## Primary-source technology references

Checked 2026-10-31. Recheck version-specific behavior when selecting and pinning the engine.

- [Resort Empire developer page and trailer link](https://www.littlegiantworld.com/games/resort-empire/).
- [Godot TileSets and isometric tile shapes](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html).
- [Godot AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html).
- [Godot UI controls and themes](https://docs.godotengine.org/en/stable/tutorials/ui/index.html).
- [Godot web export requirements and limitations](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
- [Godot multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
- [Godot save-game serialization](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html).
- [Godot licensing](https://godotengine.org/license/).
- [Phaser purpose, language support, and platform focus](https://docs.phaser.io/phaser/getting-started/what-is-phaser).
- [Aseprite documentation](https://www.aseprite.org/docs/).
- [Git LFS](https://git-lfs.com/).
- [Audacity](https://www.audacityteam.org/).

# Creative mode

Status: core policies agreed. Detailed numerical settings and save-transition behavior still need design and validation. See the [design brief](game-design-brief.md), [preproduction record](preproduction.md), and [ADR 0007](adr/0007-management-and-creative-modes.md).

## Confirmed request

The user wants admin-like controls as a Creative mode, using Minecraft Creative as an analogy for freedom to build. The actual request covers:

- Unlimited/free placement of available game content.
- Direct controls to grant in-game money.
- Instant completion of milestones.
- Fast-forward beyond the normal 1x/2x/4x controls.
- Skipping a day.

The game is single-player offline, with local autosaves and manual slots. Standard Management rules remain documented in the main brief. Unlimited placement concerns resources and progression; the user accepted retaining functional placement rules.

## Agreed policies

1. **Mode switching and saves:** Creative can be used in any existing save. Create a backup before the first Creative change and retain the edited resort when returning to Management. Switching back does not discard the player's constructions.
2. **Preset and independent powers:** provide a convenient Creative preset plus individual controls for unlimited funds, unlocking content/land, completing milestones, and adding a chosen amount of money. Exact preset values and menu organization are still to be designed.
3. **Live simulation:** guests and staff continue normally by default. Provide independent options to freeze guest needs and disable dirt or wear, allowing a functioning resort to remain visible during free building.
4. **Physical restrictions:** retain grid, terrain, overlap, path-access, and occupied-accommodation rules initially. Money, ownership, and progression barriers can be bypassed through the Creative controls. Beach construction still respects the allowed beach-facility/decor categories.
5. **Time controls:** a day skip advances the simulation through the elapsed day, including stays, payments, wages, cleaning, repairs, and departures, subject to the active Creative overrides. A separate visual time-of-day control changes the scene's lighting. Higher fast-forward options such as 8x/16x are candidates to measure, rather than guaranteed performance at every resort size.
6. **Additional tools and UI:** include spawning/removing guests, satisfying guest needs, cleaning the resort, and repairing facilities alongside money/time/unlock controls. Provide a visible Creative tools panel and a keyboard shortcut.

## Unlimited funds and remembered cash

The user accepted remembering the finite cash balance, including deliberate money grants, and restoring it when unlimited funds are disabled. Keep the numeric remembered value separate from the unlimited-funds flag. Grant/set-money controls update that remembered value and remain available through the Creative tools.

For example, enabling unlimited funds at 2,000 and deliberately granting 500 leaves a remembered finite balance of 2,500 when unlimited funds are disabled, assuming no other explicit money changes. Construction and progression changes remain in the world.

Working implementation policy: the finance view can continue reporting simulated income/expenses while unlimited funds are active; those normal flows do not change the remembered cash value, while deliberate grant/set-money actions do. Exact finance-display behavior during unlimited play will be resolved in the interface/ledger implementation.

## Open design details

- Exact Creative preset values and whether temporary settings are remembered between sessions.
- Pre-Creative backup retention and naming. General autosave, manual slots and compatibility are documented in [the README](../README.md).
- How each override affects existing needs, dirt, wear, queued jobs, and ongoing activity sessions.
- Exact day duration, time-skip presentation, cancellation, and measured fast-forward limits.
- Guest spawning options, removal/payment cleanup, and individual command feedback.

These are detailed design choices; they do not reopen the six accepted policies.

## Validation targets

- Creative state saves and reloads, and switching preserves the edited world and the pre-change backup.
- Returning to Management restores its normal active rules while retaining world changes; disabling unlimited funds restores the remembered finite cash balance, including deliberate grants.
- Advancing time processes guest and economy events once each, consistently with running the same elapsed simulation normally under the same overrides.
- Removing a guest or cleaning/repairing everything does not leave stale bookings, occupied slots, queues, or staff jobs.
- Physical placement checks remain effective in Creative, and toggles have understandable feedback.

Implementation begins only after the shared direction and next deliverable are agreed.

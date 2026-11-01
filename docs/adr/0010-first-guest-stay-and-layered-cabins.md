---
status: accepted
date: 2026-10-31
---

# One inspectable stay, exact room layers and a shared save

The next implementation requested by the user is a guest's arrival/check-in foundation and complete small stay. Whole-room sprites would hide an entering guest, and an ambient walker's random route cannot own a booking or payment.

`GuestStay` owns the first deterministic guest's reservation, route, itinerary, simple needs, nightly payments, reserve and checkout. The world advances it under the same pause/speed clock and presents it with the existing distance-driven eight-direction animation. The inspector reads its reasons and spending. Fourteen ambient walkers stay separate from this customer.

Cabin art is partitioned exactly into independently sorted floor/rear walls, bed, desk and foreground parts. Aisle fixtures use the existing source-to-grid registration. Original pixels, upright geometry, footprint reservations and real facing-specific entrances are preserved. New PNGs are deterministic derived outputs with stale-source detection, not replacement authored art.

Schema 3 saves the first stay and layout together, verifies the temporary file before replacement, retains backups and reads schemas 1/2. Occupied cabin edits and edits that would strand the guest are refused until safe. Undo/redo must keep its history when refused. Tests and captures use isolated layouts and never write the player save.

The implementation demonstrates one two-night customer and a small itinerary. It does not establish general needs planning, concurrent accommodation allocation, complete facility animation, the whole management economy, Creative state transitions or performance at the target crowd size. See [the stay proof](../guest-stay-proof.md) for balance assumptions, controls, evidence and limitations.

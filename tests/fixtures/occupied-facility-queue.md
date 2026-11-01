# Occupied facility queue replay

`occupied-facility-queue.json` is the complete actual default-world schema-4 save produced by the independent QA run at `artifacts/living-resort-qa-23460-265-queue.json` on 2026-11-01. It was generated with an isolated test save, never copied from the player. Guest states, positions, tickets, money, clock and RNG are the observed game snapshot without edits.

The solo volleyball fix changes normal leisure choices and removes that old incidental early queue. Keep a deterministic real-scene Save/restart/continuation regression by replaying the captured queue through the current full loader. The test asserts a physically queueing person, performs the actual Save action to a new artifact path, restarts and compares future complete service state. It never writes this fixture or fabricates a waiting claim. Separate tests exercise fresh unmodified natural volleyball traffic and live queues/capacity.

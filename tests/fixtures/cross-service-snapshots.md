# Cross-service restore regressions

The three `cross-service-*.json` files retain actual valid envelopes and their
single corrupted counterparts captured during the initial living-resort QA.
They are synthetic test resorts, not player saves. The corresponding six-cabin
map is built by `_crowd_map()` in `tests/living_resort_checks.gd`.

- `missing-live-tickets`: strips claims still owned by live guests.
- `orphan-ledger-person`: a valid-checksummed journal refers to an absent payer.
- `orphan-ledger-staff`: a wage refers to an absent employee.

Each positive control must restore first. Each malformed envelope must then be
rejected without changing any open service. Keeping these under `tests/fixtures`
makes `--only=backend-reject` and the complete gate independent of old local
`artifacts/` outputs. The original captures were copied byte for byte.

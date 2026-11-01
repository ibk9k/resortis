# Side missions

Status: board format and reward types agreed; individual missions and numerical balancing remain to be designed.

## Agreed direction

- An optional mission board alongside the main Management goal and milestone progression.
- Mostly untimed goals, with occasional optional timed challenges.
- Rewards such as in-game cash or decoration variants.
- Continued play after the resort reaches its top-tier goal.

Mission completion and rewards remain distinct from reputation based on guest reviews. The board should give players useful goals while allowing them to choose their building and management priorities.

## Mission families to develop

These are illustrative candidates, not additional agreed features or final criteria:

| Family | Candidate objective |
| --- | --- |
| Guest service | Complete a number of well-reviewed stays |
| Cleanliness | Maintain a clean area for an in-game period |
| Landscaping | Improve local appeal around accommodation |
| Operations | Run at positive operating profit for a period |
| Leisure | Serve guests interested in a particular facility |
| Beach activity | Complete an optional challenge using a beach facility |

Use existing resort activities and the approved facility catalogue for the first missions. Define exact conditions, progress display, reward, repeatability, and any failure/expiry behavior before implementation. Timed challenges should follow simulation time consistently with pause and fast-forward; detailed timing is a working design rule to validate.

## Integration

Mission definitions can use the content catalogue described in the technical plan. Progress and claimed rewards belong in saved state. Normal completion and Creative instant completion should use the same completion rules so reloads or repeated button presses do not grant the same one-off reward repeatedly. Repeatable mission behavior remains to be specified separately.

# Resortis visual system

## Context and direction

A player at a Windows desktop studies a sunlit, richly detailed resort for a long play session; quiet dark green tool panels keep text readable over bright sand, foliage, and water. This follows the selected v1 concept and wider-beach v3 composition.

The world has a full material palette; the interface is restrained. It serves building and observation, with focused controls and a readable inspector.

## World

- 2:1 isometric projection. Logical tile: 64 by 32 world pixels.
- One ocean edge, on the map's positive Y side. Sea appears in the foreground-left diagonal; inland grounds remain behind it.
- Wide dry sand band with separate activity and circulation space.
- Furnished cutaway cabins and warm timber service huts. Two cabin views are authored in the atlas.
- Consistent sunny light, tight contact shadows, blue-and-white fabric, lush varied planting.
- Original generated PNG atlases remain intact. AtlasTexture regions provide independent runtime sprites.

## Interface

- Surface: dark forest green (#16352f); deeper inset (#102822).
- Main text: pale cream (#fff1cf); secondary text: muted light sage (#b9cbb4).
- Active action: warm gold (#edbd68); valid placement: mint (#8cdbb0); blocked placement: coral (#f28c77).
- Font: Godot's bundled Noto Sans, with ordinary sentence case labels and clear compact text.
- Compact top bar, contextual right inspector, bottom building tray. Labels and tooltips explain shortcuts.
- Rectangular panels with restrained 4px corners and simple one-pixel boundaries. No decorative blur.
- Keyboard focus and selection have a visible outline; placement validity always includes text.

## Motion

Walking actors, gentle shoreline motion, and water shimmer make the map feel alive. Pause stops world motion. A calm-water toggle removes shader motion. Camera movement remains under the player's control.

## Current proof

This is an editable resort proof with one inspectable two-night guest stay. Maya's profile explains her activity, simple needs, budget/reserve and payments; the top bar reports revenue from that stay. The existing dark-green inspector scrolls its details while keeping follow/restart actions accessible. General bookings, wages, pricing controls, milestones, missions, full Creative powers and production save slots remain later work.

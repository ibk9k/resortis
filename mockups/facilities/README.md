# Inland facility concepts

This review mockup adds 22 inland rows to a copy of the starter map for a proposed 44 × 70 tile test footprint. The gold outline in the site render marks the expansion. Facilities are native Godot meshes at the project's shared isometric scale.

Revision two keeps the court concept, adds cutaway gym and sauna interiors, and gives the restaurant full-size chairs. The former golf plot is open test land. Review numbers are retained for easier comparison with the first pass.

Open `inland_test_plot.tscn` in Godot to rearrange the facility instances on the test land. Open any scene under `models/` to inspect or edit its geometry. `concept_models.gd` holds the editable source dimensions, layouts and palettes.

To regenerate the model scenes and the three review images, run the following from the project root with the normal Godot renderer.

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path . --script mockups/facilities/render_review.gd
```

The script checks each model against its reserved footprint and writes its review images to `artifacts/facility-review/`. This mockup is isolated from the game catalogue, simulation, buildable map and saves.

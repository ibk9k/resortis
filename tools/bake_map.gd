extends SceneTree
## Serializes the real terrain and placed objects into the editor-visible scene.

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	# Regenerate from the authoritative layout even when an old preview
	# references art that has since been removed.
	var resort := CoastalResort.new()
	resort.name = "Resortis"
	root.add_child(resort)
	await process_frame
	# Keep runtime controls and walking actors out of the authored editor preview.
	resort.hud.free()
	for walker in resort.walkers:
		walker.free()
	resort.walkers.clear()
	for node in [resort.stay_actor,resort.companion_actor,resort.volley_ball,resort.population_view,resort.management,resort.cleanliness_view]:
		if is_instance_valid(node): node.free()
	resort.camera.free()
	resort.overlay.free()
	resort.lighting.free()
	for child in resort.get_children():
		_set_owner(child, resort)
	var packed := PackedScene.new()
	var error := packed.pack(resort)
	if error == OK:
		error = ResourceSaver.save(packed, "res://scenes/world/coastal_resort.tscn")
	print("BAKED_MAP_RESULT ", error, " objects=", resort.layout.objects.size())
	quit(0 if error == OK else 1)

func _set_owner(node: Node, scene: Node) -> void:
	node.owner = scene
	for child in node.get_children():
		_set_owner(child, scene)

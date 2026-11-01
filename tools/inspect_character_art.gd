extends SceneTree
func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/illustrated-masters/guest-pair-v1.png"))
	print("CHARACTER_ART ",image.get_size()," alpha=",image.detect_alpha())
	for point in [Vector2i(0,0),Vector2i(768,512),Vector2i(200,500),Vector2i(450,500),Vector2i(1300,900)]: print(point," ",image.get_pixelv(point))
	for file in ["guest-pair-v1.png","female-turnaround-v1.png","male-turnaround-v1.png","guest-activities-v1.png"]:
		image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/illustrated-masters/"+file))
		var parts := AlphaRegions.components(image,5000)
		print("ART_COMPONENTS ",file," size=",image.get_size()," parts=",parts)
	quit()

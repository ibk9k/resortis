class_name WalkCyclePreview
extends Node2D
var sprites: Array[AnimatedSprite2D] = []
var elapsed := 0.0
var paused := false

func _ready() -> void:
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1600,0),Vector2(1600,1000),Vector2(0,1000)])
	background.color = Color("16352f")
	add_child(background)
	var title := Label.new()
	title.position = Vector2(48,48)
	title.text = "Illustrated guest walking cycles"
	title.add_theme_font_size_override("font_size",34)
	add_child(title)
	var note := Label.new()
	note.position = Vector2(48,102)
	note.text = "Female and male · eight directions · large and game-size views · Space to pause"
	note.add_theme_font_size_override("font_size",20)
	add_child(note)
	var assets := ResortAssets.new()
	var directions := HolidayGuestModel.DIRECTIONS
	for index in 16:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = assets.people_frames("female" if index<8 else "male")
		sprite.animation = directions[index%8]
		sprite.centered = false
		sprite.offset = -ResortAssets.GUEST_ROOT
		sprite.scale = Vector2.ONE*0.50
		sprite.position = Vector2(90+(index%8)*180,380+(index/8)*400)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		sprites.append(sprite)
		var label := Label.new()
		label.position = sprite.position+Vector2(-15,80)
		label.text = directions[index%8].to_upper()
		label.add_theme_font_size_override("font_size",22)
		add_child(label)
		var small := AnimatedSprite2D.new()
		small.sprite_frames=sprite.sprite_frames
		small.animation=sprite.animation
		small.centered=false
		small.offset=sprite.offset
		small.scale=Vector2.ONE*ResortAssets.GUEST_SCALE
		small.position=sprite.position+Vector2(0,70)
		small.texture_filter=sprite.texture_filter
		add_child(small)
		sprites.append(small)

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		pose(int(elapsed/1.2*HolidayGuestModel.POSES)%HolidayGuestModel.POSES)

func pose(frame: int) -> void:
	for sprite in sprites: sprite.set_frame_and_progress(frame,0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		paused = not paused

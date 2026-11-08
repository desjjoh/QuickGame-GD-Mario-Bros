extends Node2D
## Area-owned, non-colliding presentation; survives the brick's temporary marker.

const ATLAS := preload("res://assets/palettes/overworld/tileset/Palette 1 (Ground and Stone).png")
var visual_theme: AreaTheme
var _chunks: Array[Sprite2D] = []
var _y: Array[int] = [0, 8]
var _speed: Array[int] = [-6, -4]
var _speed_fraction: Array[int] = [0, 0]
var _position_fraction: Array[int] = [0, 0]
var _ticks := 0
var _elapsed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture := AtlasTexture.new()
	texture.atlas = visual_theme.resolve_texture(ATLAS) if visual_theme != null else ATLAS
	# The atlas packs four flipped copies of the 8x8 fragment.
	texture.region = Rect2(88, 32, 8, 8)
	texture.filter_clip = true
	for index in range(4):
		var chunk := Sprite2D.new()
		chunk.centered = false
		chunk.texture = texture
		add_child(chunk)
		_chunks.append(chunk)
	_update_chunks()
	var audio := AudioStreamPlayer.new()
	audio.name = "ShatterSound"
	audio.stream = SoundHandler.get_sound(&"brick_shatter")
	add_child(audio)
	audio.play()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	while _elapsed + 0.000001 >= 1.0 / 60.0:
		_elapsed -= 1.0 / 60.0
		_ticks += 1
		for pair in range(2):
			var accumulated := _position_fraction[pair] + _speed_fraction[pair]
			_y[pair] += _speed[pair] + (1 if accumulated >= 256 else 0)
			_position_fraction[pair] = accumulated % 256
			var units := _speed[pair] * 256 + _speed_fraction[pair] + 0x50
			if units >= 8 * 256 + 128:
				units = 8 * 256
			_speed[pair] = floori(units / 256.0)
			_speed_fraction[pair] = posmod(units, 256)
	_update_chunks()
	var bottom := (get_canvas_transform().affine_inverse() * get_viewport_rect().end).y
	if _speed[0] > 0 and global_position.y + _y[0] > bottom + 8:
		queue_free()


func _update_chunks() -> void:
	for index in range(4):
		var right := index % 2 == 1
		_chunks[index].position = Vector2(7 + _ticks if right else -_ticks, _y[index >> 1])
		_chunks[index].flip_h = (GameHandler.animation_clock.tick_count & 4) != 0
		_chunks[index].flip_v = (GameHandler.animation_clock.tick_count & 8) != 0

extends Node2D

const DEBRIS := preload("res://scenes/components/presentation/brick_debris.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for theme_name in ["overworld", "underground", "castle"]:
		var debris := DEBRIS.new()
		debris.visual_theme = load("res://assets/themes/%s.tres" % theme_name)
		debris.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(debris)
		debris.set_physics_process(false)
		assert(debris._chunks.size() == 4)
		assert(debris.get_child_count() == 5, "Four sprites and sound; no popup/body")
		var atlas := debris._chunks[0].texture as AtlasTexture
		assert(atlas.region == Rect2(88, 32, 8, 8))
		assert(atlas.atlas.resource_path.contains("/%s/" % theme_name))
		var audio := debris.get_node("ShatterSound") as AudioStreamPlayer
		assert(audio.bus == SoundHandler.NES_MIX_BUS)
		assert(audio.playing)
		assert(audio.volume_db == 0.0)
		assert(audio.pitch_scale == 1.0)
		debris._physics_process(1.0 / 60.0)
		assert(debris._chunks[0].position == Vector2(-1, -6))
		assert(debris._chunks[1].position == Vector2(8, -6))
		assert(debris._chunks[2].position == Vector2(-1, 4))
		debris.set_physics_process(true)
		get_tree().paused = true
		var ticks := debris._ticks
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert(debris._ticks == ticks and not audio.can_process())
		get_tree().paused = false
		# It must finish even after its originating brick no longer exists.
		for tick in range(180):
			await get_tree().physics_frame
			if not is_instance_valid(debris):
				break
		assert(not is_instance_valid(debris), "Chunks must free after falling below the screen")
	print("brick_debris_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

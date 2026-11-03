extends Node

var camera: LevelCamera
var running: bool = false
var step: int = 0

func _physics_process(_delta: float) -> void:
	if not running: return
	step += 1
	# Accelerate, brake, reverse slightly, then accelerate again at 60Hz.
	var phase := step % 160
	var speed := minf(phase / 20.0, 2.5) if phase < 80 else maxf(2.5 - (phase - 80) / 20.0, -0.5)
	camera.global_position.x += speed
	camera.force_update_scroll()

func _ready() -> void:
	process_physics_priority = 200
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	add_child(game)
	assert(game is CanvasLayer)
	var level := GameHandler.current_level
	level.player.set_gameplay_suspended(true)
	camera = get_viewport().get_camera_2d() as LevelCamera
	camera.follow_enabled = false
	camera.reset_physics_interpolation()
	if DisplayServer.get_name() != "headless":
		for frame in range(4): await RenderingServer.frame_post_draw
		var reference := get_viewport().get_texture().get_image()
		assert(reference.save_png("res://.godot/validation/hud-scroll-reference.png") == OK)
		var mismatched_frames := 0
		var maximum_changed := 0
		running = true
		for frame in range(360):
			await RenderingServer.frame_post_draw
			var shot := get_viewport().get_texture().get_image()
			var changed := 0
			# Compare every foreground glyph pixel, not just an interior point.
			# Exclude the animated coin and keep the player far below the HUD.
			for y in range(10,40):
				for x in range(16,240):
					if x >= 82 and x < 106: continue
					# World clouds can legitimately pass through transparent gaps.
					if reference.get_pixel(x,y) != Color.WHITE: continue
					if not reference.get_pixel(x,y).is_equal_approx(shot.get_pixel(x,y)):
						changed += 1
			if changed > 0:
				if mismatched_frames == 0:
					assert(shot.save_png("res://.godot/validation/hud-scroll-first-mismatch.png") == OK)
				mismatched_frames += 1
				maximum_changed = maxi(maximum_changed,changed)
		running = false
		assert(mismatched_frames == 0, "HUD changed on %s rendered frames; max %s pixels while physics camera speed varied." % [mismatched_frames,maximum_changed])
	assert(game.get_node("UI").position == Vector2.ZERO)
	game.free()
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("PASS: fixed screen-space HUD setup; rendered glyph checks skipped in headless mode.")
		get_tree().quit()
		return
	print("PASS: HUD foreground glyph pixels remain fixed through physics-driven acceleration/braking at a separate render cadence.")
	get_tree().quit()

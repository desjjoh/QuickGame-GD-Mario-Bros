extends Node

signal physics_finished

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const STAR := preload("res://scenes/entities/powerups/starman.tscn")
const STEP := 1.0 / 60.0


func _physics_process(_delta: float) -> void:
	physics_finished.emit()


func _ready() -> void:
	process_physics_priority = 2000
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	await check_painted_reward()
	await check_movement(false)
	await check_movement(true)
	check_themed_frames()
	ControllerHandler.set_physics_process(true)
	GameHandler.animation_clock.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: Starman painted reward, four-pixel pickup, palette, bounce, and wall reversal.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_themed_frames() -> void:
	for theme_name in ["overworld", "underground", "castle"]:
		var star := STAR.instantiate() as Starman
		star.visual_theme = load("res://assets/themes/%s.tres" % theme_name) as AreaTheme
		add_child(star)
		for phase in range(4):
			star.get_node("Presentation/PaletteAnimation").apply_phase(phase)
			var frame := star.sprite.texture as AtlasTexture
			assert(frame.region == Rect2(phase * 16, 0, 16, 16))
			assert(
				frame.atlas.resource_path
				== "res://assets/palettes/%s/misc/starman.png" % theme_name
			)
		star.free()


func check_painted_reward() -> void:
	var level := LEVEL.instantiate() as BaseLevel
	var area := level.get_node("Areas/MainArea") as BaseLevelArea
	var cell := Vector2i(8, 8)
	level.entity_layout.set_cell(cell, 12, Vector2i.ZERO)
	var reward := BlockReward.new()
	reward.kind = BlockReward.Kind.POWER_UP
	reward.power_up_scene = STAR
	area.question_block_rewards[cell] = reward
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	var player := level.player as Mario
	var block := level.world_objects.get_node("reward_brick_8_8") as QuestionBlock
	assert(block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
	var star := level.world_objects.get_node("Starman") as Starman
	star.set_physics_process(false)
	player.body.global_position = star.sprite.global_position + Vector2(0, 4)
	for tick in range(2):
		await get_tree().physics_frame
	if Engine.get_physics_frames() % 2 != 0:
		await get_tree().physics_frame
	assert(star.pickup.overlaps_area(player.enemy_hurtbox))
	var score := GameHandler.player_status.score
	for tick in range(1, 17):
		GameHandler.animation_clock._physics_process(STEP)
		star._physics_process(STEP)
		@warning_ignore("integer_division")
		var rise := tick / 4
		assert(star._emergence_remaining == 16 - rise)
		assert(star.is_queued_for_deletion() == (tick == 16))
		if rise > 0:
			assert(star.sprite.region_rect == Rect2(0, 0, 16, rise))
		var phase := (GameHandler.animation_clock.tick_count >> 1) & 3
		assert((star.sprite.texture as AtlasTexture).region.position.x == 16 * phase)
	assert(level.world_objects.get_node_or_null("ScorePopup") != null)
	assert(player.starman.is_active() and player.starman.intervals_remaining == 35)
	assert(GameHandler.player_status.score == score)
	for tick in range(1, 6):
		await get_tree().physics_frame
		await physics_finished
		assert(GameHandler.player_status.score == score + (1000 if tick == 5 else 0))
	assert(not is_instance_valid(star) and level.has_spawn_capacity(&"power_up"))
	level.queue_free()
	await get_tree().process_frame


func check_movement(wall: bool) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	if wall:
		var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
		for row in range(8, 14):
			ground.set_cell(Vector2i(11, row), 0, Vector2i.ZERO)
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	var star := STAR.instantiate() as Starman
	star.position = Vector2(144, 192) if wall else Vector2(128, 111)
	level.world_objects.add_child(star)
	star.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Positions from the Mesen wall and release traces, converted to body centers.
	var samples := (
		{10: Vector2(162, 200), 16: Vector2(168, 184), 17: Vector2(167, 182)}
		if wall
		else {
			1: Vector2(137, 119),
			41: Vector2(177, 200),
			66: Vector2(202, 157),
			97: Vector2(233, 200)
		}
	)
	var body := star._motion.body
	for tick in range(1, 18 if wall else 98):
		star._physics_process(STEP)
		if samples.has(tick):
			assert(
				body.global_position.is_equal_approx(samples[tick]),
				"Star motion at tick %s: %s" % [tick, body.global_position]
			)
		if tick in ([10] if wall else [41, 97]):
			assert(body.velocity.y == -180.0)
		if wall and tick == 16:
			assert(body.velocity.x == -60.0 and body.velocity.y < 0.0)
	level.queue_free()
	await get_tree().process_frame

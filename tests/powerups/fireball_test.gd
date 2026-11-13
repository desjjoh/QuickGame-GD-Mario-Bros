extends Node

const FINISH_TEST := preload("res://tests/fixtures/finish_test.gd")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const LUIGI := preload("res://scenes/player/luigi/luigi.tscn")
const FLAGPOLE := preload("res://scenes/entities/climbables/flagpole/flagpole.tscn")
const GOOMBA := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
const KOOPA := preload("res://scenes/entities/enemies/koopa/green_koopa.tscn")
const STEP := 1.0 / 60.0
signal physics_finished
# Mesen throw_idle and throw_left share this vertical trace through tick 28.
const TRACE_Y := [
	180,
	184,
	187,
	190,
	193,
	196,
	199,
	200,
	197,
	194,
	192,
	190,
	188,
	186,
	185,
	185,
	184,
	184,
	184,
	184,
	185,
	186,
	188,
	189,
	191,
	194,
	196,
	199,
	200,
	197,
	195,
	192,
	190
]
const TRACE_SPEED := [
	4,
	3,
	3,
	3,
	3,
	3,
	3,
	-3,
	-3,
	-3,
	-3,
	-2,
	-2,
	-2,
	-1,
	-1,
	-1,
	0,
	0,
	0,
	1,
	1,
	1,
	2,
	2,
	2,
	2,
	3,
	-3,
	-3,
	-3,
	-3,
	-2
]


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		await check_rendered_pose()
		print("PASS: Rendered Fire throw pixels in both directions.")
		await FINISH_TEST.finish(get_tree())
		return
	ControllerHandler.set_physics_process(false)
	await check_trace(false, false)
	await check_trace(true, false)
	await check_trace(false, true)
	await check_low_ceiling()
	await check_camera_vertical_edges()
	await check_flagpole()
	await check_slots()
	process_physics_priority = 2000
	GameHandler.animation_clock.set_physics_process(false)
	await check_enemy_hit(GOOMBA, &"Walking", 4, 152, 100)
	await check_enemy_hit(KOOPA, &"Walking", 8, 168, 200)
	await check_enemy_hit(KOOPA, &"ShellIdle", 8, 168, 200)
	await check_enemy_hit(KOOPA, &"ShellMoving", 6, 150, 200)
	await check_enemy_hit(KOOPA, &"ShellStunned", 8, 168, 200)
	await check_enemy_edge_contacts()
	GameHandler.animation_clock.set_physics_process(true)
	for luigi in [false, true]:
		await check_throw_pose(luigi, 0.0, false, 7)
		await check_throw_pose(luigi, 75.0, false, 3)
		await check_throw_pose(luigi, 150.0, false, 1)
		await check_throw_pose(luigi, 150.0, false, 2, true)
		await check_throw_pose(luigi, 0.0, true, 7)
		await check_throw_pose(luigi, 150.0, true, 2)
	ControllerHandler.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: Mesen fireball motion, slot release, and Mario/Luigi throw poses.")
	await FINISH_TEST.finish(get_tree())


func _physics_process(_delta: float) -> void:
	physics_finished.emit()


func make_level(wall: bool, luigi: bool = false, low_ceiling: bool = false) -> BaseLevel:
	var level := LEVEL.instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.FIRE
	if luigi:
		level.player_scene = LUIGI
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for column in range(16):
		ground.set_cell(Vector2i(column, 13), 0, Vector2i.ZERO)
	if wall:
		for row in range(8, 13):
			ground.set_cell(Vector2i(11, row), 0, Vector2i.ZERO)
	if low_ceiling:
		for column in [6, 7]:
			level.entity_layout.set_cell(Vector2i(column, 11), 1, Vector2i.ZERO)
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.player.body.global_position = Vector2(136, 208)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return level


func check_trace(left: bool, wall: bool) -> void:
	var level := await make_level(wall, left)
	var player := level.player as Mario
	player.sprite.flip_h = left
	var shot := player._fireballs.try_launch(player)
	assert(shot != null)
	shot.set_physics_process(false)
	var release := 16 if wall else (32 if left else 28)
	for tick in range(release + 1):
		if tick > 0:
			shot.advance()
		var motion_tick := mini(tick, 9) if wall else tick
		var x := 132 + (-4 if left else 4) * (motion_tick + 1)
		assert(shot.global_position == Vector2(x, TRACE_Y[motion_tick]), "position at %s" % tick)
		assert(shot.vertical_speed == TRACE_SPEED[motion_tick], "speed at %s" % tick)
		assert(shot.bouncing == (tick in [7, 28]), "bounce at %s" % tick)
		assert(shot.burst_tick == (tick - 9 if wall and tick >= 9 else -1))
		if wall and tick in range(10, 16):
			assert(shot.sprite.position == Vector2(-4, -4))
			assert(shot.sprite.frame == ((tick - 10) >> 1))
		assert(shot.is_queued_for_deletion() == (tick == release))
	await get_tree().process_frame
	assert(not is_instance_valid(shot))
	level.queue_free()
	await get_tree().process_frame


func check_low_ceiling() -> void:
	var level := await make_level(false, false, true)
	var player := level.player as Mario
	# Reproduce the 1-2 overhang with one tile of clearance above the floor.
	for direction: int in [-1, 1]:
		var feet_x := 160 if direction < 0 else 64
		player.body.global_position = Vector2(feet_x, 208)
		player.sprite.flip_h = direction < 0
		var shot := player._fireballs.try_launch(player)
		assert(shot != null)
		shot.set_physics_process(false)
		for tick in range(26):
			if tick > 0:
				shot.advance()
			var x := feet_x - 4 + direction * 4 * (tick + 1)
			assert(shot.global_position == Vector2(x, TRACE_Y[tick]))
			assert(shot.vertical_speed == TRACE_SPEED[tick] and shot.bouncing == (tick == 7))
			assert(shot.burst_tick == -1, "A floor bounce should clear the low bricks.")
		shot.free()

	# A shot from directly beside the brick samples solid terrain on launch.
	player.body.global_position = Vector2(92, 208)
	var close_shot := player._fireballs.try_launch(player)
	assert(close_shot != null and close_shot.bouncing and close_shot.burst_tick == -1)
	close_shot.advance()
	assert(close_shot.burst_tick == 0 and close_shot.global_position == Vector2(96, 173))
	level.queue_free()
	await get_tree().process_frame


func check_camera_vertical_edges() -> void:
	var level := await make_level(false)
	var player := level.player as Mario
	var area := level.active_area
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.position.y += 96.0
	var view := area.get_activity_region(false).grow(-area.activation_buffer)
	var top := view.position.y
	var center_x := view.get_center().x
	player.max_fireballs = 1
	for feet_offset: float in [-1.0, 27.0]:
		player.body.global_position = Vector2(center_x, top + feet_offset)
		var offscreen := player._fireballs.try_launch(player)
		assert(offscreen != null and offscreen.global_position.y < top)
		assert(offscreen.is_queued_for_deletion() and not offscreen.sprite.visible)
		assert(offscreen.burst_tick == -1)
		await get_tree().process_frame
		assert(not is_instance_valid(offscreen))

	# The launch step leaves the projectile at feet Y minus 28 pixels.
	player.body.global_position = Vector2(center_x, top + 28.0)
	var shot := player._fireballs.try_launch(player)
	assert(shot != null and shot.global_position.y == top)
	shot.set_physics_process(false)
	assert(not shot.is_queued_for_deletion() and shot.sprite.visible)
	shot.advance()
	assert(shot.global_position.y > top and not shot.is_queued_for_deletion())
	camera.position.y += 16.0
	shot.advance()
	assert(shot.is_queued_for_deletion() and not shot.sprite.visible)
	await get_tree().process_frame
	assert(not is_instance_valid(shot))

	player.body.global_position = Vector2(center_x, view.end.y + 36.0)
	var below := player._fireballs.try_launch(player)
	assert(below != null and below.is_queued_for_deletion() and not below.sprite.visible)
	level.queue_free()
	await get_tree().process_frame


func check_flagpole() -> void:
	var level := await make_level(false)
	var player := level.player as Mario
	var pole := FLAGPOLE.instantiate() as FlagpoleEntity
	pole.position = Vector2(144, 32)
	level.world_objects.add_child(pole)
	await get_tree().physics_frame
	for left in [false, true]:
		for offset in range(4):
			player.sprite.flip_h = left
			player.body.global_position = Vector2((200 if left else 136) + offset, 120)
			var shot := player._fireballs.try_launch(player)
			assert(shot != null and shot.burst_tick == -1)
			shot.set_physics_process(false)
			for tick in range(6 if left else 5):
				shot.advance()
				assert(shot.burst_tick == -1, "The transparent edge of the pole tile passes shots")
			for tick in range(5):
				shot.advance()
				if shot.burst_tick == 0:
					break
			assert(shot.burst_tick == 0, "A fireball bursts on the flagpole shaft")
			assert(is_equal_approx(shot.global_position.x, 165.0 if left else 163.0))
			assert(not shot.bouncing and not level.ending_in_progress)
			shot.queue_free()
			await get_tree().process_frame
			await get_tree().physics_frame
	level.queue_free()
	await get_tree().process_frame


func check_enemy_hit(
	scene: PackedScene, state_name: StringName, impact_tick: int, reference_x: int, points: int
) -> void:
	var level := await make_level(false)
	var player := level.player as Mario
	var enemy := scene.instantiate() as BaseEnemy
	level.world_objects.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.state_machine.change_state(enemy.state_machine.get_node(NodePath(state_name)))
	if state_name == &"ShellMoving":
		assert(enemy.body.velocity.x < 0.0)
		enemy.set("shell_chain", 2)
	enemy.body.global_position = Vector2(224, 200)
	player.stomp_chain = 2
	var score := GameHandler.player_status.score
	var clock := GameHandler.animation_clock
	var saved_tick := clock.tick_count
	clock.tick_count = 0
	var shot := player._fireballs.try_launch(player)
	assert(shot != null)
	shot.set_physics_process(false)
	# Convert the captured NES enemy origin into the centered Godot body origin.
	var before := Vector2(reference_x + 8, 184 + 16)
	for tick in range(1, impact_tick + 1):
		clock.tick_count = tick
		if tick == impact_tick:
			enemy.body.global_position = before
		shot.advance()
		assert(shot.burst_tick == (0 if tick == impact_tick else -1))
	assert(enemy._defeated and enemy.state_machine.current_state.name == &"KnockedOut")
	assert(enemy.body.global_position == before + Vector2(1, -5))
	assert(enemy.sprite.flip_v and enemy.sprite.frame == (0 if scene == GOOMBA else 4))
	var pose_top := enemy.sprite.global_position + enemy.sprite.get_rect().position
	assert(pose_top == Vector2(reference_x, 192 if scene == GOOMBA else 190))
	assert(level.world_objects.get_node_or_null("ScorePopup") != null)
	assert(GameHandler.player_status.score == score and player.stomp_chain == 2)
	if state_name == &"ShellMoving":
		assert(enemy.get("shell_chain") == 2)
	enemy._physics_process(STEP)
	assert(enemy.body.global_position == before + Vector2(1, -5), "Hit step runs once")
	# Mesen preserves live enemy Y fractions. Godot starts the launch on its own grid.
	var reference_y := [-5, -8, -11, -13, -15, -17, -18, -20]
	if scene == KOOPA:
		reference_y = [-5, -8, -10, -13, -15, -16, -18, -19]
	if state_name == &"ShellStunned":
		reference_y = [-5, -8, -10, -13, -15, -17, -18, -20]
	for tick in range(1, 8):
		await get_tree().physics_frame
		enemy._physics_process(STEP)
		shot.advance()
		assert(enemy.body.global_position.x == before.x + tick + 1)
		assert(absf(enemy.body.global_position.y - before.y - reference_y[tick]) <= 1.0)
		assert(shot.is_queued_for_deletion() == (tick == 7))
		await physics_finished
		assert(GameHandler.player_status.score == score + (points if tick >= 5 else 0))
	assert(not enemy.receive_hit(EntityHit.new(player, &"fireball", Vector2.RIGHT)))
	clock.tick_count = saved_tick
	level.queue_free()
	await get_tree().process_frame


func check_enemy_edge_contacts() -> void:
	# Each row uses the captured shot X, enemy artwork origins, and defeat count.
	for fixture in [
		[1, [-8], 0], [1, [-7], 1], [247, [255], 1], [247, [256], 0], [152, [148, 156], 2]
	]:
		var level := await make_level(false)
		var player := level.player as Mario
		var shot := player._fireballs.try_launch(player)
		assert(shot != null)
		shot.set_physics_process(false)
		var enemies: Array[BaseEnemy] = []
		var order: Array[int] = []
		for origin_x: int in fixture[1]:
			var slot := enemies.size()
			var scene := GOOMBA if slot == 0 else KOOPA
			var enemy := scene.instantiate() as BaseEnemy
			assert(level.try_claim_spawn_slot(&"enemy", enemy))
			level.world_objects.add_child(enemy)
			enemy.set_physics_process(false)
			enemy.body.global_position = Vector2(origin_x + 8, 200)
			enemy.defeated.connect(func(_hit: EntityHit): order.append(slot))
			enemies.append(enemy)
		GameHandler.animation_clock.tick_count = 2
		shot.global_position = Vector2(fixture[0] - 4, 192)
		shot._speed = 0
		shot._position_fraction = 0
		shot.advance()
		var defeated: int = fixture[2]
		assert(shot.burst_tick == (0 if defeated > 0 else -1))
		assert(order.size() == defeated)
		if defeated == 2:
			assert(order == [1, 0])
		level.queue_free()
		await get_tree().process_frame


func check_slots() -> void:
	var level := await make_level(true)
	var player := level.player as Mario
	var action: StringName = ControllerHandler.secondary_action
	var world := level.world_objects
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 1, "Fire shoots on a fresh Run press")
	var first := world.get_child(0) as Fireball
	first.set_physics_process(false)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 1, "Held Run does not shoot")
	Input.action_release(action)
	sample_run(player)
	await get_tree().process_frame
	player.body.global_position.x = 240
	Input.action_press(action)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 2, "Second fresh press uses the other slot")
	var second := world.get_child(1) as Fireball
	second.set_physics_process(false)
	Input.action_release(action)
	sample_run(player)
	for tick in range(9):
		first.advance()
	assert(first.burst_tick == 0)
	second.advance()
	second.advance()
	assert(second.is_queued_for_deletion(), "The other slot releases at the screen edge")
	await get_tree().process_frame
	player.body.global_position.x = 136
	player._throw_pose.clear()
	Input.action_press(action)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 1, "The next slot is still occupied by the burst")
	assert(not player._throw_pose.visible, "A rejected shot does not draw the throw pose")
	for tick in range(7):
		first.advance()
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 0, "Holding Run through release does not retry the shot")
	Input.action_release(action)
	sample_run(player)
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 1, "The next fresh press reuses the released slot")
	world.get_child(0).queue_free()
	Input.action_release(action)
	sample_run(player)
	player.max_fireballs = 0
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 0, "Zero limit disables fireballs")
	Input.action_release(action)
	sample_run(player)
	await get_tree().process_frame
	player.max_fireballs = 1
	Input.action_press(action)
	await get_tree().physics_frame
	sample_run(player)
	assert(world.get_child_count() == 1, "A player with one slot can still shoot")
	assert(player._fireballs.try_launch(player) == null, "Player limit of one is respected")
	Input.action_release(action)
	sample_run(player)
	level.queue_free()
	await get_tree().process_frame


func sample_run(player: Mario) -> void:
	ControllerHandler._physics_process(STEP)
	player._physics_process(STEP)


func check_throw_pose(luigi: bool, speed: float, air: bool, duration: int, skid := false) -> void:
	var level := await make_level(false, luigi)
	var player := level.player as Mario
	player._physics_process(STEP)
	assert(player.body.is_on_floor())
	player.body.velocity.x = -speed if luigi else speed
	player.sprite.flip_h = luigi
	ControllerHandler.input_left = 1.0 if luigi != skid and speed > 0.0 else 0.0
	ControllerHandler.input_right = 1.0 if luigi == skid and speed > 0.0 else 0.0
	ControllerHandler.input_secondary = true
	if air:
		player._physics_process(STEP)  # Establish the grounded cadence before takeoff.
		ControllerHandler.input_primary = true
		ControllerHandler.input_primary_just_pressed = true
		player._physics_process(STEP)
		ControllerHandler.input_primary_just_pressed = false
		assert(player.state_machine.current_state is MarioJumpState)
	ControllerHandler.input_secondary_just_pressed = true
	var pose := player._throw_pose
	for tick in range(duration + 1):
		player._physics_process(STEP)
		if tick == 0:
			var shot := level.world_objects.get_child(0) as Fireball
			assert(shot != null)
			var feet := player.body.global_position
			var expected_x := floorf(feet.x) - (8.0 if player.sprite.flip_h else 0.0)
			var expected_y := floorf(feet.y) - 28.0 if air else 180.0
			assert(shot.global_position == Vector2(expected_x, expected_y))
			assert(not shot.sprite.z_as_relative and shot.sprite.z_index == DRAW_ORDER.FIREBALL)
		assert(pose.visible == (tick < duration), "Throw duration at tick %s" % tick)
		if pose.visible:
			var walking := not air and not skid and speed > 0.0
			assert(pose._ticks_left == duration - tick - (0 if walking else 1))
			assert(pose._keep_feet == (speed > 0.0))
			if speed > 0.0:
				assert(pose._feet_texture == player.sprite.texture)
				if skid:
					assert(player.state_machine.current_state is MarioSlideState)
					assert(pose._feet_texture == player.fire_form.skid)
		ControllerHandler.input_secondary_just_pressed = false
	assert(player.sprite.self_modulate == Color.WHITE)
	assert(level.world_objects.get_child_count() == 1)
	if not air and not skid and speed == 75.0:
		pose.update_pose(4, true, true)
		player.sprite.texture = player.fire_form.walk[1]
		pose.update_pose(0, true, true)
		assert(pose._feet_texture == player.fire_form.walk[1])
		pose.clear()
	if not air and speed == 0.0:
		ControllerHandler.input_secondary_just_pressed = true
		player._physics_process(STEP)
		assert(pose.visible)
		assert(player.shrink())
		assert(not pose.visible and player.sprite.self_modulate == Color.WHITE)
	ControllerHandler._clear_input()
	level.queue_free()
	await get_tree().process_frame


func check_rendered_pose() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.position = Vector2(8, 16)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sprite)
	var pose := FireThrowPose.new()
	pose.hide()
	sprite.add_child(pose)
	var sheet := FireThrowPose.SHEET.get_image()
	var form := MarioFormPresentation.FIRE
	for base: Texture2D in [form.idle, form.walk[1], form.jump]:
		sprite.texture = base
		var keep_feet := base != form.idle
		var feet: Image
		if base is AtlasTexture:
			feet = base.atlas.get_image().get_region(Rect2i(base.region))
		else:
			feet = base.get_image()
		for left in [false, true]:
			sprite.flip_h = left
			pose.update_pose(7, base == form.walk[1], keep_feet)
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			for y in range(32):
				var source := feet if keep_feet and y >= 24 else sheet
				for x in range(16):
					var actual := image.get_pixel(x, y)
					var expected := source.get_pixel(15 - x if left else x, y)
					assert(is_equal_approx(actual.a, expected.a))
					if expected.a > 0.0:
						assert(actual.is_equal_approx(expected))
			pose.clear()
	viewport.queue_free()

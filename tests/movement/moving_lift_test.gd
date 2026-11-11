extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const SPAWNER := preload("res://scenes/entities/spawners/lift_spawner.tscn")
const SINGLE_SPAWNER := preload("res://scenes/entities/spawners/single_lift_spawner.tscn")
const STAGE_1_2 := preload("res://scenes/levels/worlds/world 1/1-2.tscn")
const STEP := 1.0 / 60.0

signal stepped


func _physics_process(_delta: float) -> void:
	stepped.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	await _check_lane(MovingLift.Direction.UP)
	await _check_lane(MovingLift.Direction.DOWN)
	await _check_1_2_pairs()
	await _check_single_lift(true)
	await _check_single_lift(false)
	print("moving_lift_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _check_lane(direction: MovingLift.Direction) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.fall_death_enabled = false
	level.keep_player_on_screen = false
	level.player_start_configuration = preload("res://assets/player/forms/small.tres")
	var area := level.get_node("Areas/MainArea") as BaseLevelArea
	for name in ["EnemyLayout", "EntityLayout", "GroundLayout"]:
		area.get_node("Layouts/" + name).clear()
	var spawner := SPAWNER.instantiate() as EntitySpawner
	spawner.direction = direction
	spawner.position = Vector2(704, -8 if direction == MovingLift.Direction.DOWN else 248)
	area.get_node("WorldObjects").add_child(spawner)
	spawner.owner = level
	add_child(level)
	var player := level.player as Mario
	player.set_physics_process(false)
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	assert(spawner.get_child_count() == 1)
	var enemies: Array[Node2D] = []
	for slot in range(5):
		var enemy := Node2D.new()
		assert(level.try_claim_spawn_slot(&"enemy", enemy))
		level.add_child(enemy)
		enemies.append(enemy)
	assert(not level.has_spawn_capacity(&"enemy"))
	camera.position.x = 640
	area.update_camera_activity()
	var lift := spawner.get_node("MovingLift") as MovingLift
	assert(lift.position == Vector2.ZERO)
	assert(lift.get_activity_rect().size == Vector2(48, 8))
	assert(not lift.activity_suspended and level.spawn_registry.get_slot(&"enemy", lift) == -1)
	assert(spawner.get_child_count() == 2)
	for tick in range(16):
		await stepped
	assert(lift.position.y == 15 * direction and lift.fraction == 0)

	lift.global_position.y = 144.0
	lift.fraction = 0
	_check_contact(player, lift)
	player.set_physics_process(true)
	for tick in range(8):
		await stepped
		assert(player.has_floor_support())
		assert(
			(
				player.body.global_position.y == lift.global_position.y
				and player.body.velocity.y == 0.0
			)
		)

	get_tree().paused = true
	var paused_y := lift.global_position.y
	await stepped
	await stepped
	assert(lift.global_position.y == paused_y and player.body.global_position.y == paused_y)
	get_tree().paused = false
	Input.action_press(ControllerHandler.primary_action)
	# The first 15 takeoff updates matched fixed ground in the Mesen lift traces.
	var jump_y := [-4, -8, -12, -16, -19, -23, -26, -29, -32, -35, -38, -40, -43, -45, -47]
	for tick in range(jump_y.size()):
		await stepped
		assert(player.state_machine.current_state is MarioJumpState)
		assert(not player.has_floor_support())
		assert(player.body.global_position.y == paused_y + jump_y[tick])
		assert(
			player.body.velocity.y == -240.0 + (tick + 1) * 7.5,
			(
				"Direction %s tick %s speed %s held %s"
				% [direction, tick, player.body.velocity.y, ControllerHandler.input_primary]
			)
		)
	Input.action_release(ControllerHandler.primary_action)
	player.set_physics_process(false)
	player.body.global_position.x = 40.0

	# Cycling the lane must succeed even while all enemy slots are occupied.
	lift.position.y = 255 * direction
	lift.fraction = 0 if direction < 0 else 15
	if direction == MovingLift.Direction.UP:
		player.body.global_position = lift.global_position + Vector2(24, 0)
		player.land_on_lift(lift)
	var player_y := player.body.global_position.y
	await stepped
	assert(lift.is_queued_for_deletion() and not player.has_floor_support())
	assert(player.body.global_position.y == player_y)
	var replacement: MovingLift
	for child in spawner.get_children():
		if child is MovingLift and child != lift:
			replacement = child
	assert(replacement != null and replacement.position.y == 0.0)
	assert(level.spawn_registry.get_slot(&"enemy", replacement) == -1)
	assert(not level.has_spawn_capacity(&"enemy"))
	await stepped
	assert(not is_instance_valid(lift))
	assert(spawner.get_child_count() == 2)

	camera.position.x = 960
	area.update_camera_activity()
	assert(replacement.is_queued_for_deletion())
	await stepped
	assert(not is_instance_valid(replacement) and not level.has_spawn_capacity(&"enemy"))
	for slot in range(enemies.size()):
		assert(level.spawn_registry.get_slot(&"enemy", enemies[slot]) == slot)
	camera.position.x = 640
	area.update_camera_activity()
	assert(spawner.get_child_count() == 1)
	level._unload_area(area)
	assert(not is_instance_valid(spawner))
	level._load_area(area)
	var reloaded := level.world_objects.get_node("LiftSpawner") as EntitySpawner
	assert(reloaded.direction == direction and not reloaded._attempted)
	assert(reloaded.get_child_count() == 1 and reloaded.has_node("StateMachine"))
	level.free()
	await stepped


func _check_1_2_pairs() -> void:
	var level := STAGE_1_2.instantiate() as BaseLevel
	level.entry_mode = BaseLevel.EntryMode.RESPAWN
	add_child(level)
	level.spawn_registry.enemy_limit = 0
	level.player.set_physics_process(false)
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	await _check_1_2_lane(level, &"DescendingLifts", 2236, MovingLift.Direction.DOWN, [112, 208])
	await _check_1_2_lane(level, &"AscendingLifts", 2476, MovingLift.Direction.UP, [16, 144])
	level.free()
	await stepped


func _check_1_2_lane(
	level: BaseLevel,
	lane_name: StringName,
	x: int,
	direction: MovingLift.Direction,
	heights: Array[int]
) -> void:
	var area := level.active_area
	var camera := area.get_node("Camera2D") as LevelCamera
	var lane := level.world_objects.get_node(NodePath(lane_name)) as EntitySpawner
	assert(area.to_local(lane.global_position).x == x)
	camera.global_position.x = lane.global_position.x - 96.0
	area.update_camera_activity()
	assert(not level.has_spawn_capacity(&"enemy"))
	# One full 256px cycle at 15/16 px per tick exercises both independent wraps.
	for tick in range(275):
		var actual: Array[int] = []
		for child in lane.get_children():
			var lift := child as MovingLift
			if lift == null or lift.is_queued_for_deletion():
				continue
			assert(lift.direction == direction)
			assert(level.spawn_registry.get_slot(&"enemy", lift) == -1)
			var y := roundi(area.to_local(lift.global_position).y)
			actual.append(posmod(y * 16 + lift.fraction, 256 * 16))
		var expected: Array[int] = []
		for height in heights:
			expected.append(posmod(height * 16 + tick * direction * 15, 256 * 16))
		actual.sort()
		expected.sort()
		assert(actual == expected, "%s tick %d: %s expected %s" % [lane_name, tick, actual, expected])
		await stepped
	camera.global_position.x = lane.global_position.x - 480.0
	area.update_camera_activity()
	await get_tree().process_frame
	assert(lane.get_child_count() == 1 and lane.has_node("StateMachine"))


func _check_single_lift(horizontal: bool) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.fall_death_enabled = false
	level.keep_player_on_screen = false
	var area := level.get_node("Areas/MainArea") as BaseLevelArea
	var spawner := SINGLE_SPAWNER.instantiate() as EntitySpawner
	spawner.axis = 0 if horizontal else 1
	spawner.position = Vector2(704, 96)
	area.get_node("WorldObjects").add_child(spawner)
	spawner.owner = level
	add_child(level)
	var player := level.player as Mario
	player.set_physics_process(false)
	level.spawn_registry.enemy_limit = 0
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	assert(not spawner.has_node("MovingLift"))
	camera.position.x = 640
	area.update_camera_activity()
	var lift := spawner.get_node("MovingLift") as MovingLift
	assert(level.spawn_registry.get_slot(&"enemy", lift) == -1)
	# Sample the Mesen paths at the recorded birth phases. Horizontal values
	# use the fresh Godot actor's zero position fraction.
	var samples := (
		{0: 0, 3: 0, 4: -1, 108: -52, 131: -52, 229: -1, 240: 0}
		if horizontal
		else {0: 0, 10: 0, 11: 1, 159: 131, 324: -7, 336: -6, 384: 0}
	)
	var clock := GameHandler.animation_clock
	var original_tick := clock.tick_count
	clock.tick_count = 136 if horizontal else 224
	player.body.velocity = Vector2.ZERO
	player.body.global_position = lift.global_position + Vector2(24, 0)
	player.land_on_lift(lift)
	var cycle_ticks := 240 if horizontal else 384
	for tick in range(cycle_ticks + 1):
		assert(player.has_floor_support())
		assert(player.body.global_position - lift.global_position == Vector2(24, 0))
		assert(player.body.velocity == Vector2.ZERO)
		if samples.has(tick):
			var displacement := lift.position.x if horizontal else lift.position.y
			assert(displacement == samples[tick], "Single lift motion differs at age %s." % tick)
		if tick < cycle_ticks:
			await stepped
	clock.tick_count = original_tick + cycle_ticks
	camera.position.x = 1120
	area.update_camera_activity()
	assert(lift.is_queued_for_deletion())
	await get_tree().process_frame
	assert(not is_instance_valid(lift))
	camera.position.x = 640
	area.update_camera_activity()
	assert(not spawner.has_node("MovingLift"))
	level.free()
	await stepped


func _check_contact(player: Mario, lift: MovingLift) -> void:
	var origin := lift.global_position
	player.body.global_position = origin + Vector2(24, 6)
	player.body.velocity = Vector2(0, 120)
	assert(not lift._check_contact(player))
	player.body.global_position.y -= 1
	assert(lift._check_contact(player))

	for head_overlap in [4, 3]:
		player.body.global_position = origin + Vector2(24, 25 - head_overlap)
		player.body.velocity.y = -232.5
		assert(not lift._check_contact(player))
		assert(player.body.velocity.y == (-232.5 if head_overlap == 4 else 67.5))

	for side in [-1, 1]:
		var x := -4 if side < 0 else 52
		player.body.global_position = origin + Vector2(x, 10)
		player.body.velocity = Vector2(-side * 90, 120)
		assert(not lift._check_contact(player))
		assert(player.body.global_position.x == origin.x + x + side)
		assert(player.body.velocity == Vector2(0, 120))

	player.body.global_position = origin + Vector2(24, -1)
	player.body.velocity = Vector2(0, 120)

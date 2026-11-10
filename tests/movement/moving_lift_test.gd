extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const SPAWNER := preload("res://scenes/entities/spawners/lift_spawner.tscn")
const STEP := 1.0 / 60.0

signal stepped


func _physics_process(_delta: float) -> void:
	stepped.emit()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	await _check_lane(MovingLift.Direction.UP)
	await _check_lane(MovingLift.Direction.DOWN)
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

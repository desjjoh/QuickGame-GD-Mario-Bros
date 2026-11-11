extends Node

const STAGE := preload("res://scenes/levels/worlds/world 1/1-2.tscn")
const SHOT := preload("res://scenes/entities/projectiles/fireball.tscn")
const KOOPA := preload("res://scenes/entities/enemies/koopa/green_koopa.tscn")
const STEP := 1.0 / 60.0
const MAIN_PIPES := [
	Vector2i(103, 10),
	Vector2i(109, 9),
	Vector2i(115, 11),
]


func _ready() -> void:
	var level := STAGE.instantiate() as BaseLevel
	level.opening_presentation = null
	level.player_start_configuration = preload("res://assets/player/forms/small.tres")
	var area := level.get_node("Areas/MainArea") as BaseLevelArea
	var surface := level.get_node("Areas/SurfaceArea") as BaseLevelArea
	assert(area.pipe_spawns.size() == MAIN_PIPES.size())
	assert(surface.pipe_spawns.keys() == [Vector2i(3, 11)])
	assert(level.get_node("Areas/IntroArea").pipe_spawns.is_empty())
	assert(level.get_node("Areas/BonusArea").pipe_spawns.is_empty())
	area.get_node("Layouts/EnemyLayout").clear()
	add_child(level)
	area.set_physics_process(false)
	var mario := level.player as Mario
	mario.set_physics_process(false)
	for cell in MAIN_PIPES:
		var pipe := (
			level.area_content.find_layout_entity(area, &"pipe_entrance", cell) as PipeEntrance
		)
		assert(pipe != null and pipe.has_node("OccupantSpawner"), str(cell))
	await get_tree().process_frame
	for id in [&"warp_4", &"warp_3", &"warp_2"]:
		var warp_pipe := area.find_transport_entity(id)
		assert(warp_pipe != null and warp_pipe.has_node("OccupantSpawner"))
	var camera := area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	var pipe := level.world_objects.get_node("pipe_entrance_103_10") as PipeEntrance
	var spawner := pipe.get_node("OccupantSpawner") as EntitySpawner
	assert(spawner.get_child_count() == 1)
	camera.global_position.x = pipe.global_position.x
	var clock := GameHandler.animation_clock
	var previous_tick := clock.tick_count
	clock.tick_count = 7
	area.update_camera_activity()
	var plant := spawner.get_node("GreenPiranhaPlant") as BaseEnemy
	assert(plant.sprite.region_rect.position.x == 16.0)
	assert(plant.body.global_position == pipe.entry_position())
	assert(plant.sprite.texture.resource_path.contains("/underground/"))
	assert(plant.sprite.z_index < level.get_node("Areas").z_index)
	assert(plant.body.collision_mask == 0 and plant.body.collision_layer == 0)
	assert(plant.body.get_node("CollisionShape2D").disabled)
	assert(not plant._block_hits.overlaps_strip(plant.get_activity_rect()))
	assert(level.spawn_registry.get_slot(&"enemy", plant) >= 0)
	plant.set_physics_process(false)

	var mouth := pipe.entry_position()
	mario.body.global_position = mouth + Vector2(0, -64)
	# Change only the cosmetic clock to verify phase boundaries independently of movement.
	var chomp_frames := {0: 16.0, 7: 16.0, 8: 0.0, 15: 0.0, 16: 16.0}
	for animation_tick in chomp_frames:
		clock.tick_count = animation_tick
		plant._physics_process(STEP)
		assert(plant.sprite.region_rect.position.x == chomp_frames[animation_tick])
	clock.tick_count = previous_tick

	for offset in [-32, 32]:
		mario.body.global_position = mouth + Vector2(offset, -64)
		for tick in range(4):
			plant._physics_process(STEP)
			assert(plant.body.global_position == mouth)
			await get_tree().physics_frame
	mario.body.global_position = mouth + Vector2(-33, -64)
	while Engine.get_physics_frames() % 2 != 0:
		await get_tree().physics_frame
	var trace := {
		0: 0, 1: -1, 46: -23, 47: -24, 110: -24, 111: -23, 156: -1, 157: 0, 220: 0, 221: -1
	}
	for tick in range(222):
		if tick == 8:
			mario.body.global_position.x = mouth.x - 25
		elif tick == 160:
			mario.body.global_position.x = mouth.x + 33
		plant._physics_process(STEP)
		if trace.has(tick):
			assert(plant.body.global_position.y == mouth.y + trace[tick], str(tick))
		await get_tree().physics_frame

	plant.body.global_position.y = mouth.y - 24
	assert(plant.projectile_target_bounds() == Rect2(mouth + Vector2(-5, -10), Vector2(10, 6)))
	_check_shell(level, plant)
	assert(not plant.receive_hit(EntityHit.new(mario, &"block_bump", Vector2.UP)))
	assert(not plant.receive_hit(EntityHit.new(mario, &"stomp", Vector2.DOWN)))
	var score := GameHandler.player_status.score
	var shot := SHOT.instantiate() as Fireball
	area.get_node("WorldObjects").add_child(shot)
	shot.set_physics_process(false)
	shot._area = area
	shot._shooter = mario
	shot._spawn_registry = level.spawn_registry
	shot.global_position = mouth + Vector2(-9, -12)
	shot._hit_enemies(area.get_activity_region(false).grow(-area.activation_buffer))
	assert(shot.burst_tick == 0 and plant._defeated)
	assert(plant.body.global_position == mouth + Vector2(0, -1) and not plant.sprite.visible)
	assert(GameHandler.player_status.score == score)
	for tick in range(6):
		await get_tree().physics_frame
	assert(GameHandler.player_status.score == score + 200)
	assert(not plant.sprite.visible)
	assert(level.spawn_registry.get_slot(&"enemy", plant) >= 0)
	camera.global_position.x = mouth.x + 156.0
	area.update_camera_activity()
	assert(plant.is_queued_for_deletion())
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not is_instance_valid(plant))
	camera.global_position.x = mouth.x
	area.update_camera_activity()
	assert(spawner.get_child_count() == 1)

	level._load_area(surface)
	var exit_pipe := (
		level.area_content.find_layout_entity(surface, &"pipe_entrance", Vector2i(3, 11))
		as PipeEntrance
	)
	assert(exit_pipe != null and exit_pipe.has_node("OccupantSpawner"))
	await _check_player_contact(level, mario)
	level.queue_free()
	await get_tree().process_frame
	print("piranha_plant_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _check_shell(level: BaseLevel, plant: BaseEnemy) -> void:
	var shell := KOOPA.instantiate() as BaseEnemy
	level.world_objects.add_child(shell)
	assert(shell.receive_hit(EntityHit.new(null, &"stomp", Vector2.DOWN)))
	assert(shell.receive_hit(EntityHit.new(null, &"kick", Vector2.RIGHT)))
	shell.body.global_position = plant.projectile_target_bounds().get_center() - Vector2(0, 5)
	assert(shell.projectile_target_bounds().intersects(plant.projectile_target_bounds(), true))
	shell.state_machine.current_state._check_enemy_hits(shell)
	assert(not plant._defeated and shell.get("shell_chain") == 0)
	shell.free()


func _check_player_contact(level: BaseLevel, mario: Mario) -> void:
	var plant := (
		level.world_objects.get_node("pipe_entrance_109_9/OccupantSpawner/GreenPiranhaPlant")
		as BaseEnemy
	)
	plant.set_physics_process(false)
	plant.body.position.y = -24
	mario.body.global_position = plant.projectile_target_bounds().position + Vector2(5, 1)
	mario.body.velocity.y = 120.0
	mario.starman.begin()
	while Engine.get_physics_frames() % 2 != 0:
		await get_tree().physics_frame
	plant._physics_process(STEP)
	assert(plant._defeated and plant.body.position.y == -1)
	assert(not plant.sprite.visible)
	assert(not mario.is_dead and mario.body.velocity.y == 120.0)
	mario.starman.clear()

	plant = level.world_objects.get_node("pipe_entrance_115_11/OccupantSpawner/GreenPiranhaPlant")
	plant.set_physics_process(false)
	plant.body.position.y = -24
	mario.body.global_position = plant.projectile_target_bounds().position + Vector2(5, 1)
	plant._physics_process(STEP)
	assert(not plant._defeated and level.death_in_progress)

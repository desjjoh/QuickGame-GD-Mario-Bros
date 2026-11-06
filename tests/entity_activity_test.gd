extends Node


func ticks(count: int = 3) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var area := load("res://scenes/levels/areas/base_area.tscn").instantiate() as BaseLevelArea
	area.get_node("Camera2D").position = Vector2(128, 120)
	add_child(area)
	var camera := area.get_node("Camera2D") as Camera2D
	area.enter_area()
	var block := (
		load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
	)
	block.position = Vector2(600, 120)
	area.get_node("WorldObjects").add_child(block)
	var block_id := block.get_instance_id()
	var original_state := block.state_machine.current_state
	assert(
		block.activity_suspended and not block.is_physics_processing() and not block.is_processing()
	)
	assert(not block.body.get_node("CollisionShape2D").disabled)
	area.enter_area()
	area.set_physics_process(false)  # Drive exact boundary cases deterministically below.
	camera.position.x = 420
	area.update_camera_activity()
	assert(not block.activity_suspended and block.is_physics_processing())
	# Remain awake in the hysteresis band, then sleep beyond the outer buffer.
	camera.position.x = 400 - 15
	area.update_camera_activity()
	assert(not block.activity_suspended)
	camera.position.x = 300
	area.update_camera_activity()
	assert(block.activity_suspended)
	camera.position.x = 335
	area.update_camera_activity()
	assert(block.activity_suspended)
	block.set_gameplay_suspended(true)
	camera.position.x = 500
	area.update_camera_activity()
	assert(
		(
			not block.activity_suspended
			and block.gameplay_suspended
			and not block.is_physics_processing()
		)
	)
	block.set_gameplay_suspended(false)
	assert(block.is_physics_processing())
	assert(
		block.get_instance_id() == block_id and block.state_machine.current_state == original_state
	)
	# Reversing suspension order must also preserve the original callbacks.
	camera.position.x = 128
	area.update_camera_activity()
	block.set_gameplay_suspended(true)
	block.set_gameplay_suspended(false)
	assert(block.activity_suspended and not block.is_physics_processing())
	camera.position.x = 500
	area.update_camera_activity()
	assert(block.is_physics_processing())
	var sync := (
		block.find_children("*", "SynchronizedAnimation", true, false)[0] as SynchronizedAnimation
	)
	assert(sync.enabled and not sync.activity_suspended)
	camera.position.x = 128
	area.update_camera_activity()
	assert(sync.enabled and sync.activity_suspended)
	await ticks(35)
	var query := PhysicsRayQueryParameters2D.create(Vector2(608, 118), Vector2(608, 140), 1)
	assert(
		not get_viewport().world_2d.direct_space_state.intersect_ray(query).is_empty(),
		"Sleeping blocks remain solid."
	)
	camera.position.x = 500
	area.update_camera_activity()
	assert(
		is_equal_approx(
			sync.animation_player.current_animation_position,
			sync.cycle.phase_time(
				sync.cycle.phase_at(
					GameHandler.animation_clock.tick_count + sync.phase_offset_ticks
				)
			)
		)
	)
	assert(sync.enabled and not sync.activity_suspended)
	# Enemy scene with a moving child body: root position alone must not drive disposal.
	var template := load("res://scenes/entities/base/base_entity.tscn").instantiate() as BaseEntity
	template.set_script(load("res://tests/fixtures/activity_enemy.gd"))
	var body := CharacterBody2D.new()
	body.name = "Body"
	template.add_child(body)
	body.owner = template
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	body.add_child(shape)
	shape.owner = template
	var packed := PackedScene.new()
	assert(packed.pack(template) == OK)
	template.free()
	var resident := packed.instantiate() as BaseEntity
	resident.position = Vector2(1200, 120)
	resident.controller_input_enabled = true
	area.get_node("WorldObjects").add_child(resident)
	await ticks()
	assert(resident.physics_ticks == 0 and resident.frame_ticks == 0)
	assert(not resident.can_read_controller_input())
	camera.position.x = 1100
	area.update_camera_activity()
	await ticks()
	assert(
		(
			resident.physics_ticks > 0
			and resident.frame_ticks > 0
			and resident.can_read_controller_input()
		)
	)
	camera.position.x = 500
	area.update_camera_activity()
	var old_ticks: int = resident.physics_ticks
	await ticks()
	assert(resident.physics_ticks == old_ticks and not resident.can_read_controller_input())
	var spawner := (
		load("res://scenes/entities/spawners/enemy_spawner.tscn").instantiate() as EnemySpawner
	)
	spawner.enemy_scene = packed
	spawner.position = Vector2(600, 120)
	area.get_node("WorldObjects").add_child(spawner)
	area.update_camera_activity()
	assert(is_instance_valid(spawner.actor))
	var first_actor: WeakRef = weakref(spawner.actor)
	await ticks()
	assert(spawner.actor.physics_ticks > 0)
	spawner.actor.get_node("Body").position.x = 1000
	area.update_camera_activity()
	assert(spawner.actor == null)
	await ticks()
	assert(first_actor.get_ref() == null)
	area.update_camera_activity()
	assert(spawner.actor == null, "Do not respawn every tick while the spawn point remains nearby.")
	camera.position.x = 128
	area.update_camera_activity()
	camera.position.x = 500
	area.update_camera_activity()
	assert(is_instance_valid(spawner.actor))
	var last_actor: WeakRef = weakref(spawner.actor)
	area.exit_area()
	assert(block.activity_suspended and not block.is_physics_processing())
	area.enter_area()
	assert(not block.activity_suspended)
	area.unload_runtime()
	await ticks()
	assert(last_actor.get_ref() == null and not area.runtime_loaded)
	assert(area._activity_entities.is_empty() and area._spawners.is_empty())
	area.free()
	# Authored residents must retain their default processing flags across templates.
	var authored_area := (
		load("res://scenes/levels/areas/base_area.tscn").instantiate() as BaseLevelArea
	)
	authored_area.get_node("Camera2D").position = Vector2(128, 120)
	var authored := packed.instantiate() as BaseEntity
	authored.name = "Resident"
	authored.position = Vector2(600, 120)
	authored_area.get_node("WorldObjects").add_child(authored)
	add_child(authored_area)
	authored_area.prepare_runtime()
	authored_area.enter_area()
	authored_area.unload_runtime()
	authored_area.load_runtime({})
	authored_area.get_node("Camera2D").position = Vector2(500, 120)
	authored_area.enter_area()
	var restored := authored_area.get_node("WorldObjects/Resident") as BaseEntity
	assert(
		(
			not restored.activity_suspended
			and restored.is_physics_processing()
			and restored.is_processing()
		)
	)
	authored_area.free()
	# No fresh enemy instances during title, death, or transitions.
	var level := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	var gated_spawner := (
		load("res://scenes/entities/spawners/enemy_spawner.tscn").instantiate() as EnemySpawner
	)
	gated_spawner.enemy_scene = packed
	gated_spawner.position = Vector2(120, 120)
	level.active_area.get_node("WorldObjects").add_child(gated_spawner)
	level.active_area.update_camera_activity()
	assert(gated_spawner.actor == null)
	level.set_physics_process(true)
	level.death_in_progress = true
	level.active_area.update_camera_activity()
	assert(gated_spawner.actor == null)
	level.death_in_progress = false
	level.transition_in_progress = true
	level.active_area.update_camera_activity()
	assert(gated_spawner.actor == null)
	level.transition_in_progress = false
	level.active_area.update_camera_activity()
	assert(is_instance_valid(gated_spawner.actor))
	level.shutdown()
	level.free()
	await ticks()
	print(
		"PASS: area-owned activity, hysteresis, resident identity/collision, suspension ownership, cosmetic sleep, enemy disposal/reentry and unload cleanup"
	)
	get_tree().quit()

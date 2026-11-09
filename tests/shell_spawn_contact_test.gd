extends Node


func ticks(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
	ground.clear()
	for x in range(-8, 70):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.body.global_position = Vector2(100, 50)
	var camera := level.active_area.get_node("Camera2D") as LevelCamera
	camera.follow_enabled = false
	camera.position = Vector2(128, 120)
	await ticks(2)
	camera.position.x = 688
	var pair := (
		load("res://scenes/entities/spawners/goomba_pair_spawner.tscn").instantiate()
		as EntitySpawner
	)
	pair.position = Vector2(816, 192)
	level.world_objects.add_child(pair)
	var shell := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	shell.position = Vector2(794, 192)
	level.world_objects.add_child(shell)
	assert(shell.receive_hit(EntityHit.new(null, &"stomp", Vector2.DOWN)))
	assert(shell.receive_hit(EntityHit.new(null, &"kick", Vector2.ZERO)))
	shell.get_node("StateMachine/ShellMoving")._direction = 1
	camera.position.x = 689
	level.active_area.update_camera_activity()
	var target := pair.get_node("Goomba") as BaseEnemy
	var far_target: BaseEnemy
	for child in pair.get_children():
		if child is BaseEnemy and child != target:
			far_target = child as BaseEnemy
	assert(is_instance_valid(far_target))
	target.set_gameplay_suspended(true)
	await ticks(5)
	assert(not target._defeated)
	var moving := shell.get_node("StateMachine/ShellMoving")
	assert(not moving._touching.has(target.get_instance_id()))
	shell.set_physics_process(false)
	await ticks(6)  # Finish setup awards without moving past the suspended target.
	shell.set_physics_process(true)
	var score := GameHandler.player_status.score
	target.set_gameplay_suspended(false)
	for frame in range(8):
		await ticks(1)
		if target._defeated:
			break
	assert(
		target._defeated, "A temporarily rejected shell contact must retry while overlap continues."
	)
	assert(shell.get("shell_chain") == 1)
	shell.set_physics_process(false)
	await ticks(6)
	assert(GameHandler.player_status.score == score + 500)
	moving._on_enemy_contact(target)
	assert(GameHandler.player_status.score == score + 500)
	shell.set_physics_process(true)
	await ticks(12)
	assert(shell.body.global_position.x > far_target.body.global_position.x)
	assert(not far_target._defeated and shell.get("shell_chain") == 1)
	shell.free()
	pair.free()
	level.queue_free()
	await ticks(2)
	print("shell_spawn_contact_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

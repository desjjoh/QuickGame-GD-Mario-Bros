extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var stage := load("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	var layout := stage.get_node("Areas/MainArea/Layouts/EnemyLayout") as TileMapLayer
	assert(layout.get_cell_source_id(Vector2i(214, 23)) == 2)
	var count := 0
	for cell in layout.get_used_cells():
		if layout.get_cell_source_id(cell) == 2:
			count += 1
	assert(count == 1)
	stage.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	level.player.set_physics_process(false)
	level.player.body.global_position = Vector2(24, 150)
	var koopa := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	koopa.position = Vector2(144, 192)
	level.world_objects.add_child(koopa)
	var idle = koopa.get_node("StateMachine/ShellIdle")
	var walking = koopa.get_node("StateMachine/Walking")
	assert(koopa.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
	await ticks(250)
	assert(koopa.state_machine.current_state == idle)
	assert(idle.wake_ticks_remaining == 86)
	await ticks(idle.wake_ticks_remaining - 84)
	assert(idle.wake_ticks_remaining == 84)
	var frames := {}
	for index in range(16):
		await ticks(1)
		frames[koopa.sprite.frame] = true
	assert(frames.has(4) and frames.has(9))
	var remaining: int = idle.wake_ticks_remaining
	var pose := koopa.sprite.frame
	var clock := GameHandler.animation_clock.tick_count
	assert(GameHandler.request_pause_toggle())
	await ticks(12)
	assert(idle.wake_ticks_remaining == remaining and koopa.sprite.frame == pose)
	assert(GameHandler.animation_clock.tick_count == clock)
	assert(GameHandler.request_pause_toggle())
	await ticks(remaining - 1)
	assert(koopa.state_machine.current_state == idle)
	await ticks(1)
	assert(koopa.state_machine.current_state == walking and koopa._can_hurt_player())
	assert(koopa.sprite.vframes == 1 and koopa.sprite.position == Vector2(0, -8))
	assert(walking._direction == (1 if GameHandler.animation_clock.tick_count % 2 == 0 else -1))
	assert(koopa.get_node("WalkAnimationSync").enabled)
	assert(koopa.sprite.frame == int(GameHandler.animation_clock.tick_count / 8) % 2)
	assert(koopa.receive_hit(EntityHit.new(level.player, &"stomp", Vector2.DOWN)))
	assert(idle.wake_ticks_remaining == 336)
	assert(koopa.receive_hit(EntityHit.new(level.player, &"kick", Vector2.ZERO)))
	await ticks(20)
	assert(idle.wake_ticks_remaining == 336)
	game.queue_free()
	await ticks(2)
	print("koopa_wake_test: PASS")
	get_tree().quit()

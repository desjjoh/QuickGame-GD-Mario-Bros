extends Node


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var player := level.player
	player.set_physics_process(false)
	player.body.global_position = Vector2(128, 100)
	var score := GameHandler.player_status.score
	var lives := GameHandler.player_status.lives
	var expected := [100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000]
	assert(BasePlayer.STOMP_CHAIN_POINTS == expected)
	var earned := 0
	for index in range(13):
		var path := (
			"res://scenes/entities/enemies/goomba/goomba.tscn"
			if index % 2 == 0
			else "res://scenes/entities/enemies/koopa/green_koopa.tscn"
		)
		var enemy := load(path).instantiate() as BaseEnemy
		enemy.position = Vector2(192, 160)
		level.world_objects.add_child(enemy)
		assert(enemy.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		await ticks(6)
		if index < 10:
			earned += expected[index]
		assert(GameHandler.player_status.score == score + earned)
		assert(GameHandler.player_status.lives == lives + maxi(0, index - 9))
		var count := player.stomp_chain
		assert(not enemy.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
		assert(player.stomp_chain == count)
		# Stopping a moving shell uses this same player's continuing stomp chain.
		if index == 11:
			assert(enemy.receive_hit(EntityHit.new(player, &"kick", Vector2.ZERO)))
			lives += 1  # Kick at the saturated airborne chain also awards a life.
			assert(enemy.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
			lives += 1
			await ticks(6)
			assert(GameHandler.player_status.lives == lives + 2)
		enemy.queue_free()
	assert(GameHandler.request_pause_toggle())
	await ticks(12)
	assert(player.stomp_chain == 10)
	assert(GameHandler.request_pause_toggle())
	# Land using the actual shared player motion path.
	player.body.global_position = Vector2(128, 180)
	player.body.velocity = Vector2(0, 120)
	for index in range(40):
		player.move_body()
		if player.body.is_on_floor():
			break
		await ticks(1)
	assert(player.body.is_on_floor() and player.stomp_chain == 0)
	var fresh := load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	fresh.position = Vector2(192, 160)
	level.world_objects.add_child(fresh)
	var before := GameHandler.player_status.score
	assert(fresh.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	await ticks(6)
	assert(GameHandler.player_status.score == before + 100 and player.stomp_chain == 1)

	# Two Goombas 16 pixels apart can both overlap the same descending player.
	var goomba_scene := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
	var pair: Array[BaseEnemy] = []
	player.body.global_position = Vector2(128, 100)
	player.body.velocity.x = 150.0
	assert(player.jump_action.begin(player.motion_values, true))
	player.body.velocity = Vector2(0, 120)
	player.jump_action.update(player.motion_values, true)
	player.stomp_chain = 0
	before = GameHandler.player_status.score
	for offset in [-8, 8]:
		var goomba := goomba_scene.instantiate() as BaseEnemy
		level.world_objects.add_child(goomba)
		goomba.body.global_position = player.body.global_position + Vector2(offset, 0)
		pair.append(goomba)
	await ticks(2)
	for goomba in pair:
		assert(goomba.state_machine.current_state == goomba.get_node("StateMachine/Squashed"))
	assert(player.body.velocity.y == BaseEnemy.STOMP_REBOUND and not level.death_in_progress)
	assert(player.stomp_chain == 2)
	# Keep Jump held through the rebound from a full-speed jump.
	var stomp_y := player.body.global_position.y
	var apex_y := stomp_y
	for frame in range(16):
		player.jump_action.update(player.motion_values, true)
		assert(player.motion_values.gravity == 2025.0)
		player.move_body(true)
		apex_y = minf(apex_y, player.body.global_position.y)
		if player.body.velocity.y >= 0.0:
			break
		await ticks(1)
	assert(is_equal_approx(stomp_y - apex_y, 17.0))
	player.jump_action.end(player.motion_values)
	await ticks(6)
	assert(GameHandler.player_status.score == before + 100 + 400)

	# A later stomp uses the third chain entry, with no leftover same-tick bonus.
	var next_goomba := goomba_scene.instantiate() as BaseEnemy
	next_goomba.position = Vector2(192, 160)
	level.world_objects.add_child(next_goomba)
	assert(next_goomba.receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)))
	await ticks(6)
	assert(GameHandler.player_status.score == before + 100 + 400 + 400)
	assert(player.stomp_chain == 3)
	player.begin_death()
	assert(player.stomp_chain == 0)
	game.queue_free()
	await ticks(2)
	print("stomp_chain_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

extends Node

signal physics_finished

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const GOOMBA := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
const KOOPA := preload("res://scenes/entities/enemies/koopa/green_koopa.tscn")
const STEP := 1.0 / 60.0


func _physics_process(_delta: float) -> void:
	physics_finished.emit()


func _ready() -> void:
	process_physics_priority = 2000
	await _check_hit(GOOMBA, &"Walking", 136, 100)
	await _check_hit(GOOMBA, &"Squashed", 136, 100)
	await _check_hit(KOOPA, &"Walking", 136, 200)
	await _check_hit(KOOPA, &"ShellIdle", 136, 200)
	await _check_hit(KOOPA, &"ShellMoving", 134, 200)
	await _check_hit(KOOPA, &"ShellStunned", 136, 200)
	GameHandler.clear_session()
	print("PASS: Starman contact priority, Mesen launch, old pose, and delayed enemy scores.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _check_hit(scene: PackedScene, state: StringName, reference_x: int, points: int) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	add_child(level)
	level.set_physics_process(false)
	var player := level.player as Mario
	player.set_physics_process(false)
	var form := player.small_form if scene == GOOMBA and state == &"Walking" else player.fire_form
	player.form_controller.configure(player, form)
	player.body.global_position = Vector2(136, 208)
	player.body.velocity.y = 60.0
	player.stomp_chain = 2
	player.starman.begin()
	var enemy := scene.instantiate() as BaseEnemy
	level.world_objects.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.state_machine.change_state(enemy.state_machine.get_state(state))
	if state == &"Squashed":
		# The trace seeds the squashed state, with no earlier stomp award pending.
		enemy._defeated = true
	var before := Vector2(reference_x + 8, 200)
	enemy.body.global_position = before
	var edge_contact := scene == KOOPA and state == &"Walking"
	if edge_contact:
		player.body.global_position.x = before.x - 13.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	await physics_finished
	if Engine.get_physics_frames() % 2 != 0:
		await physics_finished
	if edge_contact:
		assert(not enemy._touches_player_now(player))
		player.body.global_position.x += 1.0
		assert(not enemy._player_contact_area.overlaps_area(player.enemy_hurtbox))
		assert(enemy._touches_player_now(player), "The current box edges are touching.")
	else:
		assert(enemy._touches_player_now(player))
	var score := GameHandler.player_status.score
	var old_sprite_position := enemy.sprite.global_position
	var old_frame := enemy.sprite.frame
	var old_flip := enemy.sprite.flip_v
	enemy._physics_process(STEP)
	assert(enemy._defeated and enemy.state_machine.current_state.name == &"KnockedOut")
	assert(enemy.body.global_position == before + Vector2(1, -5))
	assert(enemy.sprite.global_position == old_sprite_position)
	assert(enemy.sprite.frame == old_frame and enemy.sprite.flip_v == old_flip)
	assert(player.stomp_chain == 2 and player.body.velocity.y == 60.0)
	assert(level.world_objects.get_node_or_null("ScorePopup") != null)
	assert(GameHandler.player_status.score == score)
	enemy._physics_process(STEP)
	assert(enemy.body.global_position == before + Vector2(1, -5))
	# Sampled NES positions relative to the pre-contact body. The squashed
	# fixture carries an existing Y fraction into the shared launch.
	var offsets := [-5, -8, -11, -13, -15, -17, -18, -20]
	if state == &"Squashed":
		offsets = [-5, -8, -10, -12, -14, -16, -18, -19]
	for tick in range(1, offsets.size()):
		await get_tree().physics_frame
		enemy._physics_process(STEP)
		assert(enemy.body.global_position.x == before.x + tick + 1)
		var tolerance := 1.0 if state == &"Squashed" else 0.0
		assert(absf(enemy.body.global_position.y - before.y - offsets[tick]) <= tolerance)
		assert(enemy.sprite.frame == (0 if scene == GOOMBA else 4))
		assert(enemy.sprite.flip_v == (scene == GOOMBA))
		if tick == 1:
			var pose_top := enemy.sprite.global_position + enemy.sprite.get_rect().position
			assert(pose_top == Vector2(reference_x + 1, 189 if scene == GOOMBA else 187))
		await physics_finished
		assert(GameHandler.player_status.score == score + (points if tick >= 5 else 0))
	assert(not enemy.receive_hit(EntityHit.new(player, &"star", Vector2.ZERO)))
	level.queue_free()
	await get_tree().process_frame

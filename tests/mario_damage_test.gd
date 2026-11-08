extends Node


func ticks(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func advance(mario: Mario) -> void:
	GameHandler.animation_clock.tick_count += 1
	mario.form_presentation._physics_process(1.0 / 60.0)
	mario.damage._physics_process(1.0 / 60.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SUPER
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	var mario := level.player as Mario
	mario.set_physics_process(false)
	mario.form_presentation.set_physics_process(false)
	mario.damage.set_physics_process(false)
	var goomba := (
		load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	)
	goomba.position = Vector2(120, 192)
	level.world_objects.add_child(goomba)
	goomba.set_physics_process(false)
	mario.body.global_position = Vector2(128, 208)
	mario.body.velocity = Vector2.ZERO
	var lives := GameHandler.player_status.lives
	goomba._player_contact_latched = true
	goomba._handle_player_contact(mario)
	assert(not goomba._player_contact_latched)
	assert(not mario.is_dead and not level.death_in_progress)
	assert(GameHandler.player_status.lives == lives)
	assert(mario.form_presentation.active and mario.damage.is_protected())
	assert(GameHandler.player_status.powerup_form == PlayerStatus.PowerupForm.SMALL)
	assert(mario._active_sound_effect.stream == SoundHandler.get_sound(&"injury"))
	assert(SoundHandler.get_sound(&"injury") == SoundHandler.get_sound(&"pipe"))
	assert(
		(
			mario._active_sound_effect.volume_db == 0.0
			and mario._active_sound_effect.pitch_scale == 1.0
		)
	)
	assert(not mario.receive_damage(goomba))
	while mario.form_presentation.active:
		advance(mario)
		assert(mario.damage.intervals_remaining == 8)
	assert(mario.form_controller.current_form == MarioFormPresentation.SMALL)
	assert(mario.damage.is_protected())
	# Protection survives shrink completion, flashes, and freezes under user pause.
	advance(mario)
	assert(mario.sprite.visible == (GameHandler.animation_clock.tick_count % 2 == 0))
	advance(mario)
	assert(mario.sprite.visible == (GameHandler.animation_clock.tick_count % 2 == 0))
	mario.damage.set_physics_process(true)
	get_tree().paused = true
	var remaining := mario.damage._interval_ticks
	await ticks(2)
	assert(mario.damage._interval_ticks == remaining)
	get_tree().paused = false
	mario.damage.set_physics_process(false)
	# Actual Area2D overlap persists through expiry; rejected damage cannot latch it away.
	await ticks(2)
	assert(goomba._player_contact_area.overlaps_area(mario.enemy_hurtbox))
	goomba._player_contact_latched = true
	goomba._handle_player_contact(mario)
	assert(not goomba._player_contact_latched)
	assert(not mario.is_dead and GameHandler.player_status.lives == lives)
	# Protection prevents injury, while normal descending stomps still work.
	var stomp_target := (
		load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	)
	stomp_target.position = Vector2(200, 192)
	level.world_objects.add_child(stomp_target)
	stomp_target.set_physics_process(false)
	mario.body.velocity.y = 60.0
	stomp_target._handle_player_contact(mario)
	assert(stomp_target._defeated and mario.body.velocity.y == BaseEnemy.STOMP_REBOUND)
	assert(mario.damage.is_protected())
	mario.body.velocity = Vector2.ZERO
	var elapsed := 2
	while mario.damage.is_protected():
		advance(mario)
		elapsed += 1
	assert(elapsed >= 148 and elapsed <= 168)
	assert(mario.sprite.visible)
	# Stop enemy movement while exercising the real overlap/contact polling path.
	goomba.state_machine.gameplay_suspended = true
	for index in range(4):
		await ticks(1)
		goomba._physics_process(1.0 / 60.0)
		if mario.is_dead:
			break
	assert(mario.is_dead and level.death_in_progress)
	assert(GameHandler.player_status.lives == lives - 1)
	assert(not mario.receive_damage(goomba))
	assert(GameHandler.player_status.lives == lives - 1)
	level.free()
	# Walking Koopas and moving shells use the same ordinary damage entry point.
	for moving_shell in [false, true]:
		level = load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
		level.player_start_configuration = MarioFormPresentation.SUPER
		level.entity_layout.clear()
		level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
		add_child(level)
		mario = level.player as Mario
		var koopa := (
			load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
		)
		level.world_objects.add_child(koopa)
		if moving_shell:
			assert(koopa.state_machine.change_state(koopa.get_node("StateMachine/ShellMoving")))
		mario.body.velocity = Vector2.ZERO
		koopa._handle_player_contact(mario)
		assert(mario.form_presentation.active and mario.damage.is_protected() and not mario.is_dead)
		level.free()
	# Protection must never intercept the level's lethal hazard path.
	level = load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SUPER
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	mario = level.player as Mario
	assert(mario.receive_damage())
	assert(mario.damage.is_protected())
	assert(level.on_death(mario, false, BaseLevel.DeathReason.TIMEOUT))
	assert(mario.is_dead and not mario.damage.is_protected() and mario.sprite.visible)
	level.free()
	print(
		"PASS: Super contact shrinks with injury cue/protection/blink; persistent overlap hurts after expiry; Small damage and timeout remain lethal; pause freezes protection."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

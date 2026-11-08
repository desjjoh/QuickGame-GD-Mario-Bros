extends Node


func _ready() -> void:
	var small := load("res://assets/player/forms/small.tres") as MarioForm
	var super_form := load("res://assets/player/forms/super.tres") as MarioForm
	assert(small.walk.size() == 3 and super_form.walk.size() == 3)
	assert(super_form.climb.size() == 2 and super_form.can_crouch and super_form.can_break_bricks)
	assert(not small.can_crouch and not small.can_break_bricks)
	assert(super_form.growth_intermediate.get_size() == Vector2(16, 32))
	assert(super_form.crouched_contact_size == Vector2(12, 12))
	var stage := load("res://scenes/levels/worlds/world 1/1-1.tscn").instantiate() as BaseLevel
	assert(stage.player_start_configuration == null)
	stage.free()
	var level := load("res://tests/fixtures/silent_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = super_form
	add_child(level)
	var mario := level.player as Mario
	mario.set_physics_process(false)
	assert(mario.form_controller.current_form == super_form)
	var identity := mario.get_instance_id()
	var body_id := mario.body.get_instance_id()
	var machine_id := mario.state_machine.get_instance_id()
	var feet := mario.body.global_position
	assert(mario.collision_shape.shape.size == Vector2(11, 14))
	assert(mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size == Vector2(12, 24))
	assert(mario.enemy_hurtbox.position == Vector2(0, -12))
	assert(mario.sprite.position == Vector2(0, -15))
	assert(mario.sprite.position.y + mario.sprite.texture.get_height() / 2.0 == 1)
	for entry in [
		["Jump", super_form.jump],
		["Slide", super_form.skid],
		["PipeEnter", super_form.idle],
		["Idle", super_form.idle]
	]:
		assert(mario.state_machine.change_state(mario.get_node("StateMachine/" + entry[0])))
		assert(mario.sprite.texture == entry[1])
	# Check the actual texture keys sampled by both animations, not only state metadata.
	for name in [&"walk", &"climb"]:
		var frames: Array[Texture2D] = super_form.walk if name == &"walk" else super_form.climb
		var clip := mario.animation_player.get_animation(name)
		mario.animation_player.play(name)
		for key in range(frames.size()):
			mario.animation_player.seek(clip.track_get_key_time(0, key), true)
			assert(mario.sprite.texture == frames[key])
	# Mid-cycle configuration preserves actor, motion, state and animation phase.
	assert(mario.state_machine.change_state(mario.get_node("StateMachine/Move")))
	mario.animation_player.seek(0.14, true)
	var state := mario.state_machine.current_state
	mario.form_controller.configure(mario, small)
	assert(mario.form_controller.current_form == small)
	assert(mario.state_machine.current_state == state)
	assert(is_equal_approx(mario.animation_player.current_animation_position, 0.14))
	assert(mario.sprite.texture == small.walk[1])
	assert(mario.sprite.position == Vector2(0, -7))
	assert(mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size == Vector2(10, 12))
	assert(mario.body.global_position == feet)
	assert(mario.get_instance_id() == identity and mario.body.get_instance_id() == body_id)
	assert(mario.state_machine.get_instance_id() == machine_id and level.player == mario)
	mario.form_controller.configure(mario, super_form)
	assert(mario.state_machine.change_state(mario.get_node("StateMachine/Dead")))
	assert(mario.sprite.texture.resource_path.ends_with("mario-dead.png"))
	assert(mario.sprite.position == Vector2(0, -7))
	# A separate default Mario must not inherit the fixture's resources or overrides.
	var ordinary := load("res://scenes/player/mario/mario.tscn").instantiate() as Mario
	add_child(ordinary)
	assert(ordinary.form_controller.current_form == small)
	assert(ordinary.get_node("StateMachine/Jump").sprite_texture == small.jump)
	assert(
		ordinary.animation_player.get_animation("walk").track_get_key_value(0, 0) == small.walk[0]
	)
	assert(
		mario.animation_player.get_animation("walk").track_get_key_value(0, 0) == super_form.walk[0]
	)
	ordinary.queue_free()
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("mario_form_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

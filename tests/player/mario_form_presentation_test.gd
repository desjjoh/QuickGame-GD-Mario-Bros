extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	var mario := level.player as Mario
	mario.set_physics_process(false)
	var presentation := mario.form_presentation
	presentation.set_physics_process(false)
	mario.starman.set_physics_process(false)
	var actor_id := mario.get_instance_id()
	var state := mario.state_machine.current_state
	var witness := (
		load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate() as BaseEntity
	)
	level.world_objects.add_child(witness)
	# A pre-existing suspension must survive the transformation's release.
	var already_suspended := witness.duplicate() as BaseEntity
	level.world_objects.add_child(already_suspended)
	already_suspended.set_gameplay_suspended(true)
	for shrink in [false, true]:
		for phase in range(4):
			mario.form_controller.configure(
				mario, MarioFormPresentation.SUPER if shrink else MarioFormPresentation.SMALL
			)
			mario.body.velocity = Vector2(60, -100)
			state = mario.state_machine.current_state
			var feet := mario.body.global_position
			var velocity := mario.body.velocity
			GameHandler.animation_clock.tick_count = phase
			var with_starman: bool = not shrink and phase == 0
			if with_starman:
				mario.starman.begin()
			assert(mario.shrink() if shrink else mario.grow())
			assert(not presentation.begin(shrink))
			assert(witness.gameplay_suspended and already_suspended.gameplay_suspended)
			assert(level.player_presentation == presentation)
			var end_timer := 0xc8 if shrink else 0xc4
			for elapsed in range(1, 0xff - end_timer + 2):
				GameHandler.animation_clock.tick_count += 1
				presentation._physics_process(1.0 / 60.0)
				if with_starman:
					mario.starman._physics_process(1.0 / 60.0)
					var palette_slot := ((elapsed - 1) >> 1) & 3
					assert(mario.starman.palette_slot == palette_slot)
					assert(mario._throw_pose.visible == (palette_slot != 0))
				if presentation.blocks_actor_motion():
					mario._physics_process(1.0 / 60.0)
				assert(presentation.timer == (0xff - elapsed if elapsed < 0xff - end_timer else 0))
				assert(mario.get_instance_id() == actor_id)
				assert(not presentation.active or mario.state_machine.current_state == state)
				assert(mario.body.global_position == feet and mario.body.velocity == velocity)
				var switch_tick := 15 if shrink else 7
				var expected_form: MarioForm
				if elapsed < switch_tick:
					expected_form = (
						MarioFormPresentation.SUPER if shrink else MarioFormPresentation.SMALL
					)
				else:
					expected_form = (
						MarioFormPresentation.SMALL if shrink else MarioFormPresentation.SUPER
					)
				assert(mario.form_controller.current_form == expected_form)
				if presentation.changing:
					var texture: Texture2D
					if shrink:
						texture = (
							(
								MarioFormPresentation.SMALL
								if presentation.pose_index % 2 == 0
								else MarioFormPresentation.SUPER
							)
							. shrink_pose
						)
					else:
						texture = [
							MarioFormPresentation.SMALL.idle,
							MarioFormPresentation.SUPER.growth_intermediate,
							MarioFormPresentation.SUPER.idle
						][MarioFormPresentation.GROWTH_POSES[presentation.pose_index]]
					assert(mario.sprite.texture == texture)
					assert(mario.sprite.position.y + texture.get_height() / 2.0 == 1.0)
				if presentation.active and presentation._cycle_finished:
					assert(mario.sprite.texture != null)
			assert(not presentation.active and level.player_presentation == null)
			assert(not witness.gameplay_suspended and already_suspended.gameplay_suspended)
			assert(mario.sprite.visible and not mario.state_machine.gameplay_suspended)
			if with_starman:
				mario.starman.clear()
	# Real SceneTree pause stops the component even though the test keeps processing.
	mario.form_controller.configure(mario, MarioFormPresentation.SMALL)
	assert(mario.grow())
	presentation.set_physics_process(true)
	get_tree().paused = true
	var timer := presentation.timer
	await get_tree().process_frame
	await get_tree().process_frame
	assert(presentation.timer == timer)
	get_tree().paused = false
	presentation.set_physics_process(false)
	# Area-arrival cancellation releases the world and settles the accepted form.
	mario.on_area_arrival()
	assert(not presentation.active and not witness.gameplay_suspended)
	assert(mario.form_controller.current_form == MarioFormPresentation.SUPER)
	assert(mario.shrink())
	while not presentation._cycle_finished:
		GameHandler.animation_clock.tick_count += 1
		presentation._physics_process(1.0 / 60.0)
	var before_tail := mario.body.global_position
	mario._physics_process(1.0 / 60.0)
	assert(mario.body.global_position == before_tail)
	assert(witness.gameplay_suspended)
	# Death cancellation must release our lock before death applies its own.
	level.on_death(mario, false)
	assert(not presentation.active and witness.gameplay_suspended)
	level.shutdown()
	assert(not presentation.active and level.player_presentation == null)
	level.free()
	print(
		"PASS: form sequences match timer/pose/profile changes across four clock phases; identity, feet, suspension, pause and teardown preserved."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

extends Node


func _ready() -> void:
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SMALL
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	var mario := level.player as Mario
	mario.set_physics_process(false)
	mario.form_presentation.set_physics_process(false)
	mario.damage.set_physics_process(false)
	var comparisons := 0
	for injury in [false, true]:
		for jumping in [false, true]:
			mario.damage.clear()
			mario.form_controller.configure(
				mario, MarioFormPresentation.SUPER if injury else MarioFormPresentation.SMALL
			)
			mario.state_machine.change_state(
				mario.get_node("StateMachine/Jump" if jumping else "StateMachine/Move")
			)
			mario.animation_player.pause()
			mario.body.velocity = Vector2(60 if jumping else 150, -180 if jumping else 0)
			mario.form_presentation._walk_frame = 0
			mario.form_presentation._walk_timer = 0
			GameHandler.animation_clock.tick_count = 218
			var feet := mario.body.global_position
			assert(mario.receive_damage() if injury else mario.grow())
			var case_name := ("damage" if injury else "growth") + ("_jump" if jumping else "_run")
			var trace := FileAccess.open(
				"res://docs/archive/reference/transformation-mesen-" + case_name + ".csv",
				FileAccess.READ
			)
			trace.get_csv_line()
			var stop_clock := 274 if injury else 278
			while not trace.eof_reached():
				var row := trace.get_csv_line()
				if row.size() < 15:
					continue
				var clock := int(row[0]) - 123
				if clock < 218:
					continue
				if clock > stop_clock:
					break
				if clock > 218:
					GameHandler.animation_clock.tick_count = clock
					mario.form_presentation._physics_process(1.0 / 60.0)
				var textures := {
					0: MarioFormPresentation.SUPER.walk[2],
					8: MarioFormPresentation.SUPER.walk[0],
					16: MarioFormPresentation.SUPER.walk[1],
					32: MarioFormPresentation.SUPER.jump,
					40: MarioFormPresentation.SUPER.shrink_pose,
					96: MarioFormPresentation.SMALL.walk[2],
					104: MarioFormPresentation.SMALL.walk[0],
					112: MarioFormPresentation.SMALL.walk[1],
					128: MarioFormPresentation.SMALL.jump,
					136: MarioFormPresentation.SMALL.shrink_pose,
					184: MarioFormPresentation.SMALL.idle,
					192: MarioFormPresentation.SUPER.growth_intermediate,
					200: MarioFormPresentation.SUPER.idle
				}
				if not injury or clock % 2 == 0:
					assert(
						mario.sprite.texture == textures[int(row[9])],
						case_name + " pose mismatch clock " + str(clock)
					)
					comparisons += 1
				if clock < stop_clock:
					assert(
						mario.form_presentation.blocks_actor_motion(),
						case_name + " premature movement"
					)
					mario._physics_process(1.0 / 60.0)
					assert(mario.body.global_position == feet)
			assert(not mario.form_presentation.active)
			assert(not mario.state_machine.gameplay_suspended)
			if not injury:
				assert(mario.state_machine.current_state.name == "Move")
			mario.damage.clear()
	level.free()
	print(
		"PASS: ",
		comparisons,
		" visible frame poses match the four captured Mesen timelines, including entry, closing draw and release boundaries."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

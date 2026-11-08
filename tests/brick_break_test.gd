extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControllerHandler.set_physics_process(false)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	canvas.add_child(level)
	var player := level.player as Mario
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for form in [MarioFormPresentation.SMALL, MarioFormPresentation.SUPER]:
		player.form_controller.configure(player, form)
		for crouched in [false, true]:
			player.form_controller.set_crouched(crouched)
			for scene in [
				"brick/brick_block",
				"brick/alternate_brick_block",
				"question/question_block",
				"question/reward_brick",
				"question/alternate_reward_brick"
			]:
				var block := (
					load("res://scenes/entities/blocks/" + scene + ".tscn").instantiate()
					as BaseBlock
				)
				block.position = Vector2(128, 128)
				level.world_objects.add_child(block)
				player.bonk_action.reset_reaction_gate()
				player.body.global_position = Vector2(136, 172)
				player.body.velocity = Vector2(90, -240)
				var expected_break: bool = scene.begins_with("brick/") and form.can_break_bricks
				var score_before := GameHandler.player_status.score
				assert(player.bonk_action.deliver_at(player, block.body))
				var previous_sound := player._active_sound_effect
				player.respond_to_ceiling()
				if expected_break:
					assert(GameHandler.player_status.score == score_before + 50)
					assert(player.bonk_action.suppress_ceiling_sound)
					assert(
						player._active_sound_effect == previous_sound,
						"Shatter itself must not play a bump pulse"
					)
					assert(block.state_machine.current_state.name == &"Broken")
					assert(block.body.collision_layer != 0 and not block.visible)
					assert(
						player.body.velocity == Vector2(90, -120),
						"Break must preserve integer impulse and X"
					)
					assert(
						not player.bonk_action.deliver_at(player, block.body),
						"Broken brick cannot accept another hit"
					)
					assert(GameHandler.player_status.score == score_before + 50)
					assert(
						not player.bonk_action.suppress_ceiling_sound,
						"Following solid contact can play bump"
					)
					get_tree().paused = true
					await get_tree().process_frame
					await get_tree().process_frame
					assert(
						is_instance_valid(block) and block.body.collision_layer != 0,
						"Pause must retain temporary marker"
					)
					get_tree().paused = false
					await get_tree().physics_frame
					await get_tree().physics_frame
					await get_tree().process_frame
					assert(not is_instance_valid(block), "Broken brick must free")
				else:
					assert(block.state_machine.current_state.name == &"Bouncing")
					assert(block.body.collision_layer != 0 and block.visible)
					assert(is_nan(player.bonk_action.response_velocity_y))
					if block is QuestionBlock:
						block.state_machine.change_state(block.get_node("StateMachine/Inactive"))
						assert(
							not player.bonk_action.deliver_at(player, block.body),
							"Depleted reward blocks must remain solid"
						)
						assert(
							block.body.collision_layer != 0 and not block.is_queued_for_deletion()
						)
					block.free()
	canvas.free()
	ControllerHandler.set_physics_process(true)
	print("brick_break_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

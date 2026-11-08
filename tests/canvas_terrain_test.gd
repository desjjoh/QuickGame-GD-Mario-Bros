extends Node

signal stepped
var pending: Callable
var player: Mario


func _physics_process(_delta: float) -> void:
	if pending.is_valid():
		var action := pending
		pending = Callable()
		action.call()
		stepped.emit()


func step(action: Callable) -> void:
	pending = action
	await stepped


func _ready() -> void:
	process_physics_priority = 200
	ControllerHandler.set_physics_process(false)
	for wrapped in [false, true]:
		var level := load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
		level.player_start_configuration = load("res://assets/player/forms/super.tres")
		level.entity_layout.clear()
		level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
		var ground := level.get_node("Areas/MainArea/Layouts/GroundLayout") as TileMapLayer
		ground.clear()
		for x in range(24):
			ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
		var container: Node = CanvasLayer.new() if wrapped else Node2D.new()
		add_child(container)
		container.add_child(level)
		level.set_physics_process(false)
		level.active_area.set_physics_process(false)
		player = level.player as Mario
		player.set_physics_process(false)
		for kind in ["ground", "brick", "question", "used"]:
			for direction in [-1.0, 1.0]:
				for feet in [164.0, 165.0, 173.0]:
					var block: BaseBlock
					if kind == "ground":
						ground.set_cell(Vector2i(8, 8), 0, Vector2i.ZERO)
					else:
						var path := (
							"res://scenes/entities/blocks/brick/brick_block.tscn"
							if kind == "brick"
							else "res://scenes/entities/blocks/question/question_block.tscn"
						)
						block = load(path).instantiate() as BaseBlock
						block.position = Vector2(128, 128)
						level.world_objects.add_child(block)
						if kind == "used":
							block.state_machine.change_state(
								block.get_node("StateMachine/Inactive")
							)
					await get_tree().physics_frame
					var coins: int = GameHandler.get_session_value(&"coins")
					await step(
						func():
							player.bonk_action.reset_reaction_gate()
							player.vertical_movement.reset_fraction()
							player.state_machine.stop(false)
							player.body.global_position = Vector2(
								126 if direction > 0 else 146, feet
							)
							player.body.velocity = Vector2.ZERO
							player.body.move_and_slide()
							assert(
								player.body.global_position.y == feet,
								"Fixture must not depenetrate before jump"
							)
							player.jump_action.active = true
							player.jump_action.falling_gravity = 2025
							player.jump_action.set("_released", false)
							player.jump_action.set("_rise", 450.0)
							player.state_machine.change_state(player.get_node("StateMachine/Jump"))
							player.body.velocity = Vector2(150 * direction, -60)
							ControllerHandler.input_right = 1 if direction > 0 else 0
							ControllerHandler.input_left = 1 if direction < 0 else 0
							ControllerHandler.input_primary = true
							ControllerHandler.input_primary_just_pressed = false
					)
					await step(func(): player._physics_process(1.0 / 60.0))
					var context := "%s canvas=%s feet=%s dir=%s" % [kind, wrapped, feet, direction]
					assert(player.body.global_position.y == feet - 1, "No head snap: " + context)
					if feet < 173:
						assert(player.body.velocity.x == 0, "Side contact must stop X: " + context)
					else:
						assert(
							player.body.velocity.x * direction > 0,
							"Head-only contact must retain X: " + context
						)
					if feet == 173:
						assert(
							player.body.velocity.y < 0,
							"Exact underside boundary must remain unbonked"
						)
						await step(func(): player._physics_process(1.0 / 60.0))
					var bounce: bool = feet != 164 and kind in ["brick", "question"]
					if feet == 164:
						assert(player.body.velocity.y < 0, "Phase 3 must retain rise: " + context)
					else:
						if bounce:
							assert(
								(
									floori(player.body.velocity.y / 60.0)
									== (-2 if kind == "brick" else 0)
								),
								"Accepted block integer response: " + context
							)
						else:
							assert(
								floori(player.body.velocity.y / 60.0) == 1,
								"Solid integer response: " + context
							)
					for tick in range(10):
						await step(func(): player._physics_process(1.0 / 60.0))
					assert(
						(
							GameHandler.get_session_value(&"coins")
							== coins + (1 if bounce and kind == "question" else 0)
						),
						"Reward must occur exactly once: " + context
					)
					assert(
						not Rect2(128, 128, 16, 16).has_point(player.get_head_position()),
						"Head must clear naturally: " + context
					)
					if kind == "used":
						assert(
							not block.bounce.is_running(),
							"Used block must have no bounce presentation"
						)
					ground.erase_cell(Vector2i(8, 8))
					if is_instance_valid(block):
						block.free()
		container.free()
	ControllerHandler.input_left = 0
	ControllerHandler.input_right = 0
	ControllerHandler.input_primary = false
	ControllerHandler.set_physics_process(true)
	print("canvas_terrain_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

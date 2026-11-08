extends Node


func ticks(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var game = load("res://scenes/main/game.tscn").instantiate()
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	var level: BaseLevel = GameHandler.current_level
	var mario := level.player as Mario
	await ticks(3)
	assert(mario.grow())
	await mario.form_presentation.finished
	var pipe: PipeEntrance
	for item in level.active_area.get_node("WorldObjects").get_children():
		if (
			item is PipeEntrance
			and item.entrance_enabled
			and not item.sideways
			and item.get_destination().area_id == &"lower"
		):
			pipe = item
			break
	assert(pipe != null)
	print("ACTUAL PIPE ", pipe.name, " at ", pipe.global_position)
	mario.body.global_position = pipe.global_position + Vector2(16, -1)
	mario.body.velocity = Vector2.ZERO
	level.active_area.get_node("Camera2D").snap_to_arrival(mario.body)
	await ticks(4)
	print(
		"BEFORE PIPE crouched=",
		mario.form_controller.is_crouched,
		" hurt=",
		mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size
	)
	Input.action_press(ControllerHandler.down_action)
	var source := level.active_area
	for i in range(180):
		await ticks(1)
		if level.area_transport.pending:
			Input.action_release(ControllerHandler.down_action)
		if level.active_area != source:
			break
	assert(level.active_area != source)
	await ticks(4)
	Input.action_release(ControllerHandler.down_action)
	await ticks(4)
	print(
		"SECRET ARRIVAL crouched=",
		mario.form_controller.is_crouched,
		" hurt=",
		mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size,
		" head=",
		mario.get_head_position() - mario.body.global_position
	)
	mario.set_physics_process(false)
	level.set_physics_process(false)
	var coins: Array = []
	for item in level.active_area.get_node("WorldObjects").get_children():
		if item.get_script() == load("res://scenes/entities/coin/coin.gd"):
			coins.append(item)
	assert(not coins.is_empty())
	var coin: BaseEntity = coins[coins.size() / 2]
	mario.body.global_position = coin.global_position + Vector2(8, 32)
	mario.body.velocity = Vector2.ZERO
	mario.body.reset_physics_interpolation()
	var before := GameHandler.player_status.coins
	await ticks(2)
	assert(not mario.form_controller.is_crouched)
	assert(coin.capture_area_state().is_empty())
	mario.move_body()
	assert(coin.capture_area_state().get("state") == &"Collected")
	assert(GameHandler.player_status.coins == before + 1)
	print(
		"HEAD CONTACT coin=",
		coin.name,
		" at ",
		coin.global_position,
		" feet=",
		mario.body.global_position,
		" crouched=",
		mario.form_controller.is_crouched,
		" hurt=",
		mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size,
		" support=",
		mario.collision_shape.shape.size,
		" collected=",
		coin.capture_area_state(),
		" coins=",
		GameHandler.player_status.coins - before
	)
	await ticks(2)
	mario.move_body()
	assert(GameHandler.player_status.coins == before + 2)
	assert(mario.enemy_hurtbox.get_node("CollisionShape2D").shape.size == Vector2(12, 24))
	print(
		"PASS: actual 1-1 secret pipe trip, standing Super upper-body coin collection, and one coin per probe update."
	)
	game.free()
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

extends Node

const BLOCK_COIN := preload("res://scenes/entities/blocks/question/block_coin.gd")
const LEVEL := preload("res://scenes/levels/worlds/world 1/1-1.tscn")


func ticks(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func effects(level: BaseLevel) -> Array[Node]:
	return level.world_objects.get_children().filter(
		func(child: Node) -> bool: return child.get_script() == BLOCK_COIN
	)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControllerHandler.set_physics_process(false)
	for use_canvas in [false, true]:
		for breaking in [false, true]:
			await check_hit(use_canvas, breaking)
	ControllerHandler.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: block_top_coin_test")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_hit(use_canvas: bool, breaking: bool) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	var markers := level.get_node("Areas/MainArea/Layouts/EntityLayout") as TileMapLayer
	markers.clear()
	markers.set_cell(Vector2i(4, 9), 0, Vector2i.ZERO)
	markers.set_cell(Vector2i(4, 8), 7, Vector2i.ZERO)
	markers.set_cell(Vector2i(5, 8), 7, Vector2i.ZERO)
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	var canvas: CanvasLayer
	if use_canvas:
		canvas = CanvasLayer.new()
		add_child(canvas)
		canvas.add_child(level)
	else:
		add_child(level)
	var player := level.player as Mario
	player.set_physics_process(false)
	var form := MarioFormPresentation.SUPER if breaking else MarioFormPresentation.SMALL
	player.form_controller.configure(player, form)
	var brick := level.world_objects.get_node("brick_4_9") as BaseBlock
	var coin := level.world_objects.get_node("coin_4_8") as WorldCoin
	var neighbor := level.world_objects.get_node("coin_5_8") as WorldCoin
	await ticks(2)
	GameHandler.set_coins(99 if breaking else 10)
	var score := GameHandler.player_status.score
	var lives := GameHandler.player_status.lives
	var origin := coin.sprite.global_position
	var hit := EntityHit.new(player, &"bonk", Vector2.UP)
	assert(brick.receive_hit(hit))
	assert(GameHandler.player_status.coins == (0 if breaking else 11))
	assert(GameHandler.player_status.score == score + (250 if breaking else 200))
	assert(GameHandler.player_status.lives == lives + int(breaking))
	assert(coin.capture_area_state().state == &"Collected")
	assert(neighbor.capture_area_state().is_empty())
	# The terrain query can still see the area before its deferred mask update.
	assert(not coin.collect(player))
	assert(not brick.receive_hit(hit))
	assert(effects(level).size() == 1)
	var effect := effects(level)[0] as Sprite2D
	assert(effect.global_position == origin)
	get_tree().paused = true
	await ticks(2)
	assert(effect.global_position == origin)
	get_tree().paused = false
	await ticks(1)
	assert(effect.global_position.y < origin.y)

	assert(level.request_area_transfer(&"lower"))
	await ticks(2)
	assert(not is_instance_valid(effect))
	assert(level.request_area_transfer(&"main", &"player_spawn"))
	await ticks(2)
	coin = level.world_objects.get_node("coin_4_8") as WorldCoin
	neighbor = level.world_objects.get_node("coin_5_8") as WorldCoin
	brick = level.world_objects.get_node("brick_4_9") as BaseBlock
	assert(coin.capture_area_state().state == &"Collected")
	assert(neighbor.capture_area_state().is_empty())
	assert(brick.receive_hit(hit))
	assert(GameHandler.player_status.coins == (0 if breaking else 11))
	assert(GameHandler.player_status.score == score + (300 if breaking else 200))
	assert(effects(level).is_empty())
	if canvas != null:
		canvas.free()
	else:
		level.free()
	await ticks(2)

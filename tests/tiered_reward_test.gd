extends Node

const LEVEL := preload("res://scenes/levels/worlds/world 1/1-1.tscn")
const LUIGI := preload("res://scenes/player/luigi/luigi.tscn")
const MUSHROOM := preload("res://scenes/entities/powerups/super_mushroom.tscn")
const FLOWER := preload("res://scenes/entities/powerups/fire_flower.tscn")
const ONE_UP := preload("res://scenes/entities/powerups/one_up_mushroom.tscn")


func _ready() -> void:
	ControllerHandler.set_physics_process(false)
	assert(BlockReward.resolve(MUSHROOM).kind == BlockReward.Kind.TIERED_POWER_UP)
	assert(BlockReward.resolve(FLOWER).power_up_scene == FLOWER)
	assert(BlockReward.resolve(ONE_UP).power_up_scene == ONE_UP)
	for is_luigi in [false, true]:
		for form_index in range(3):
			await check_release(is_luigi, form_index)
	ControllerHandler.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: tiered reward selection at release for Mario and Luigi in all three forms.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_release(is_luigi: bool, form_index: int) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	if is_luigi:
		level.player_scene = LUIGI
	add_child(level)
	level.set_physics_process(false)
	var player := level.player as Mario
	player.set_physics_process(false)
	var block := level.world_objects.get_node("question_block_21_9") as QuestionBlock
	assert(block.reward_kind == BlockReward.Kind.TIERED_POWER_UP)
	block.set_activity_suspended(false)
	# Change form after the authored reward has been resolved, without a session form update.
	var forms := [player.small_form, player.super_form, player.fire_form]
	player.form_controller.configure(player, forms[form_index])
	var previous: PowerUp
	if form_index == 2:
		previous = MUSHROOM.instantiate() as PowerUp
		assert(level.try_claim_spawn_slot(&"power_up", previous))
		level.world_objects.add_child(previous)
	var score := GameHandler.player_status.score
	var coins := GameHandler.player_status.coins
	var hit := EntityHit.new(player, &"bonk", Vector2.UP)
	assert(block.receive_hit(hit))
	var expected := MUSHROOM if form_index == 0 else FLOWER
	var item_name := "SuperMushroom" if form_index == 0 else "FireFlower"
	var item := level.world_objects.get_node(item_name) as PowerUp
	assert(item.scene_file_path == expected.resource_path)
	assert(item.global_position == block.global_position and item._emergence_remaining == 16)
	if previous != null:
		assert(previous.is_queued_for_deletion())
	assert(not level.has_spawn_capacity(&"power_up"))
	assert(not block.receive_hit(hit))
	assert(block.capture_area_state().state == &"Inactive")
	assert(GameHandler.player_status.score == score and GameHandler.player_status.coins == coins)
	level.queue_free()
	await get_tree().process_frame

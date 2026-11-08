extends Node

const SUPER := preload("res://scenes/entities/powerups/super_mushroom.tscn")


func ticks(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SMALL
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	var mario := level.player as Mario
	mario.set_physics_process(false)
	mario.body.global_position = Vector2(256, 208)
	var score := GameHandler.player_status.score
	var lives := GameHandler.player_status.lives
	var mushroom: SuperMushroom
	for path in [
		"res://scenes/entities/blocks/question/question_block.tscn",
		"res://scenes/entities/blocks/question/hidden_question_block.tscn",
		"res://scenes/entities/blocks/question/reward_brick.tscn",
		"res://scenes/entities/blocks/question/alternate_reward_brick.tscn"
	]:
		var block := load(path).instantiate() as QuestionBlock
		block.configure_reward(SUPER)
		block.position = Vector2(64, 144)
		level.world_objects.add_child(block)
		assert(block.receive_hit(EntityHit.new(mario, &"bonk", Vector2.UP)))
		mushroom = level.world_objects.get_node("SuperMushroom") as SuperMushroom
		mushroom.set_physics_process(false)
		assert(mushroom._emergence_remaining == 16 and not mushroom.pickup.monitoring)
		assert(mario.body in mushroom.body.get_collision_exceptions())
		mushroom._on_pickup_overlap(mario.enemy_hurtbox)
		assert(not mushroom._removing and GameHandler.player_status.score == score)
		block.queue_free()
		if path.ends_with("alternate_reward_brick.tscn"):
			break
		mushroom.queue_free()
		await ticks(2)
	var voice := SoundHandler.get_node("Square2Sfx") as AudioStreamPlayer
	assert(voice.stream == SoundHandler.get_sound(&"power_up_reveal"))
	for index in range(64):
		mushroom._physics_process(1.0 / 60.0)
	assert(mushroom.position == Vector2(64, 128))
	assert(mushroom._emergence_remaining == 0 and not mushroom.sprite.region_enabled)
	var pickup_position := mushroom.sprite.global_position
	await ticks(2)
	# Actual overlap grants the reward once and starts growth on this same actor.
	mario.body.global_position = mushroom.body.global_position + Vector2(0, 8)
	var actor_id := mario.get_instance_id()
	await ticks(4)
	assert(not is_instance_valid(mushroom))
	assert(GameHandler.player_status.score == score + 1000)
	assert(GameHandler.player_status.lives == lives and mario.form_presentation.active)
	assert(voice.stream == SoundHandler.get_sound(&"power_up_grab"))
	assert(voice.volume_db == 0.0 and voice.pitch_scale == 1.0)
	var popup := level.world_objects.get_node("ScorePopup") as Sprite2D
	assert(popup.visible and popup.region_rect == Rect2(16, 0, 16, 8))
	assert(popup.global_position.x == pickup_position.x)
	assert(
		(
			popup.global_position.y <= pickup_position.y
			and popup.global_position.y > pickup_position.y - 4
		)
	)
	await mario.form_presentation.finished
	assert(mario.get_instance_id() == actor_id)
	assert(mario.form_controller.current_form == MarioFormPresentation.SUPER)
	assert(level.has_spawn_capacity(&"power_up"))
	# Already-Super collection gives the same 1,000 points without another transition.
	mushroom = SUPER.instantiate() as SuperMushroom
	mushroom.position = Vector2(160, 192)
	assert(level.try_claim_spawn_slot(&"power_up", mushroom))
	level.world_objects.add_child(mushroom)
	mushroom.set_physics_process(false)
	mario.body.global_position = mushroom.body.global_position + Vector2(0, 8)
	await ticks(4)
	assert(not is_instance_valid(mushroom))
	assert(GameHandler.player_status.score == score + 2000)
	assert(GameHandler.player_status.lives == lives and not mario.form_presentation.active)
	# A contact begun during a suspended transformation is retried after release.
	mushroom = SUPER.instantiate() as SuperMushroom
	mushroom.position = Vector2(120, 192)
	mushroom.walk_speed = 0.0
	mushroom.gravity = 0.0
	assert(level.try_claim_spawn_slot(&"power_up", mushroom))
	level.world_objects.add_child(mushroom)
	assert(mario.shrink())
	mario.body.global_position = Vector2(128, 208)
	await ticks(2)
	assert(is_instance_valid(mushroom) and GameHandler.player_status.score == score + 2000)
	await mario.form_presentation.finished
	await ticks(4)
	assert(not is_instance_valid(mushroom))
	assert(GameHandler.player_status.score == score + 3000 and mario.form_presentation.active)
	await mario.form_presentation.finished
	# Available mushrooms use the inherited walking/falling and cleanup path.
	mushroom = SUPER.instantiate() as SuperMushroom
	mushroom.position = Vector2(200, 160)
	assert(level.try_claim_spawn_slot(&"power_up", mushroom))
	level.world_objects.add_child(mushroom)
	mushroom.set_physics_process(false)
	var before := mushroom.body.global_position
	mushroom._physics_process(1.0 / 60.0)
	assert(mushroom.body.global_position.x > before.x and mushroom.body.velocity.y > 0)
	var cleanup := level.active_area.get_activity_region(true)
	mushroom.body.global_position.x = cleanup.end.x + 32
	level.active_area.update_camera_activity()
	await ticks(2)
	assert(not is_instance_valid(mushroom))
	assert(
		GameHandler.player_status.score == score + 3000 and level.has_spawn_capacity(&"power_up")
	)
	assert((SoundHandler.get_sound(&"power_up_grab") as AudioStreamWAV).data.size() == 54 * 735 * 2)
	level.free()
	print(
		"PASS: Super Mushroom releases from all reward blocks, grows Small, awards 1000 once for either form, displays popup/plays cue, and reuses movement/cleanup."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

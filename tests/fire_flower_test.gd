extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const FLOWER := preload("res://scenes/entities/powerups/fire_flower.tscn")
const LUIGI := preload("res://scenes/player/luigi/luigi.tscn")
const QUESTION := preload("res://scenes/entities/blocks/question/question_block.tscn")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
const FORMS := [
	MarioFormPresentation.SMALL, MarioFormPresentation.SUPER, MarioFormPresentation.FIRE
]


func _ready() -> void:
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	for is_luigi in [false, true]:
		for index in range(FORMS.size()):
			await check_pickup(is_luigi, index)
	ControllerHandler.set_physics_process(true)
	GameHandler.animation_clock.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: Flower rise, global palette, stationary body, and six character/form pickups.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_pickup(is_luigi: bool, index: int) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	level.player_start_configuration = FORMS[index]
	if is_luigi:
		level.player_scene = LUIGI
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	var player := level.player as Mario
	player.set_physics_process(false)
	var forms := [player.small_form, player.super_form, player.fire_form]
	assert(player.form_controller.current_form == forms[index])
	GameHandler.set_player_form(index)
	var score := GameHandler.player_status.score
	var block := QUESTION.instantiate() as QuestionBlock
	block.configure_reward(FLOWER)
	block.position = Vector2(128, 128)
	level.world_objects.add_child(block)
	assert(block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
	var flower := level.world_objects.get_node("FireFlower") as PowerUp
	var world := level.get_node("Areas") as CanvasItem
	assert(not world.z_as_relative and world.z_index == DRAW_ORDER.WORLD)
	flower.set_physics_process(false)
	assert(not flower.sprite.visible and not flower._can_pick_up_at_current_height())
	assert(
		(
			(SoundHandler.get_node("Square2Sfx") as AudioStreamPlayer).stream
			== SoundHandler.get_sound(&"power_up_reveal")
		)
	)
	for tick in range(1, 65):
		GameHandler.animation_clock._physics_process(1.0 / 60.0)
		flower._physics_process(1.0 / 60.0)
		@warning_ignore("integer_division")
		var rise := tick / 4
		assert(flower.position == Vector2(128, 128 - rise))
		assert(flower.sprite.visible == (rise > 0))
		var priority := DRAW_ORDER.AVAILABLE_ITEM if rise == 16 else DRAW_ORDER.BEHIND_WORLD
		assert(not flower.sprite.z_as_relative and flower.sprite.z_index == priority)
		if rise > 0 and rise < 16:
			assert(flower.sprite.region_enabled)
			assert(flower.sprite.region_rect == Rect2(0, 0, 16, rise))
		var phase := (GameHandler.animation_clock.tick_count >> 1) & 3
		assert((flower.sprite.texture as AtlasTexture).region.position.x == 16 * phase)
		if tick == 16 and index == 0 and not is_luigi and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			assert(frame.save_png("res://.godot/validation/fire-flower-emerging.png") == OK)
	assert(not flower.sprite.region_enabled)
	await get_tree().process_frame
	assert(flower.pickup.monitoring)
	assert(not level.has_spawn_capacity(&"power_up"))
	var anchor := flower.sprite.global_position
	flower.set_physics_process(true)
	await ticks(8)
	assert(flower.sprite.global_position == anchor)
	if index == 0:
		await get_tree().physics_frame
		if Engine.get_physics_frames() % 2 == 0:
			await get_tree().physics_frame
		player.body.global_position = anchor + Vector2(-11, 8)
		flower._physics_process(1.0 / 60.0)
		assert(not flower.is_queued_for_deletion())
		player.body.global_position.x -= 1.0
		await get_tree().physics_frame
		player.body.global_position.x += 1.0
		assert(not flower.pickup.overlaps_area(player.enemy_hurtbox))
		flower._physics_process(1.0 / 60.0)
		assert(flower.is_queued_for_deletion())
	else:
		player.body.global_position = anchor + Vector2(0, 8)
	await ticks(3)
	assert(not is_instance_valid(flower))
	assert(GameHandler.player_status.score == score)
	assert(player.form_presentation.active == (index != 2))
	assert(GameHandler.player_status.powerup_form == mini(index + 1, 2))
	var popup := level.world_objects.get_node("ScorePopup") as Sprite2D
	assert(popup.region_rect == Rect2(16, 0, 16, 8) and popup.global_position.x == anchor.x)
	assert(
		(
			(SoundHandler.get_node("Square2Sfx") as AudioStreamPlayer).stream
			== SoundHandler.get_sound(&"power_up_grab")
		)
	)
	await ticks(8)
	assert(GameHandler.player_status.score == score + 1000)
	if player.form_presentation.active:
		await player.form_presentation.finished
	assert(player.form_controller.current_form == forms[mini(index + 1, 2)])
	assert(level.has_spawn_capacity(&"power_up"))
	level.queue_free()
	await get_tree().process_frame


func ticks(count: int) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

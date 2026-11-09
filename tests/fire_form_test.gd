extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const LUIGI := preload("res://scenes/player/luigi/luigi.tscn")
const FIRE := preload("res://assets/player/forms/fire.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	for is_luigi in [false, true]:
		await check_fire(is_luigi)
	ControllerHandler.set_physics_process(true)
	GameHandler.animation_clock.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: shared Fire art, palette timing, pause, damage and character-specific Small form.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_fire(is_luigi: bool) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.player_start_configuration = MarioFormPresentation.SUPER
	if is_luigi:
		level.player_scene = LUIGI
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	var player := level.player as Mario
	player.set_physics_process(false)
	var presentation := player.form_presentation
	presentation.set_physics_process(false)
	player.damage.set_physics_process(false)
	var original_material := player.sprite.material
	var state := player.state_machine.current_state
	var feet := player.body.global_position
	var size := (player.enemy_hurtbox.get_node("CollisionShape2D").shape as RectangleShape2D).size
	GameHandler.animation_clock.tick_count = 50 if is_luigi else 186
	assert(player.ignite() and not player.ignite())
	assert(player.form_controller.current_form == FIRE and player.sprite.texture == FIRE.idle)
	assert(GameHandler.player_status.powerup_form == PlayerStatus.PowerupForm.FIRE)
	assert(
		(player.enemy_hurtbox.get_node("CollisionShape2D").shape as RectangleShape2D).size == size
	)
	assert(level.player_presentation == presentation and presentation.blocks_actor_motion())
	presentation.set_physics_process(true)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert(presentation.timer == 255)
	get_tree().paused = false
	presentation.set_physics_process(false)
	for elapsed in range(64):
		if elapsed > 0:
			GameHandler.animation_clock.tick_count += 1
			presentation._physics_process(1.0 / 60.0)
		assert(player.sprite.texture == FIRE.idle and player.body.global_position == feet)
		assert(player.state_machine.current_state == state)
		assert(presentation.active and presentation.blocks_actor_motion())
		assert(presentation.timer == (255 - elapsed if elapsed < 63 else 0))
		var material := player.sprite.material as ShaderMaterial
		var light: Color = material.get_shader_parameter(&"light_color")
		var middle: Color = material.get_shader_parameter(&"middle_color")
		var dark: Color = material.get_shader_parameter(&"dark_color")
		var palette := (
			["f7d8a5e69c21b53120", "109400ffffffe69c21", "b53120ffffffe69c21", "000000ffcec59c4a00"]
			. find(light.to_html(false) + middle.to_html(false) + dark.to_html(false))
		)
		assert(palette >= 0)
		print("FIRE,%s,%d,%d" % ["luigi" if is_luigi else "mario", elapsed, palette])
		if elapsed == 2 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture := "res://.godot/validation/fire-form-%s.png" % player.name
			assert(get_viewport().get_texture().get_image().save_png(capture) == OK)
	GameHandler.animation_clock.tick_count += 1
	presentation._physics_process(1.0 / 60.0)
	assert(not presentation.active and not presentation.blocks_actor_motion())
	assert(level.player_presentation == null and player.sprite.material == original_material)
	assert(player.receive_damage() and player.damage.is_protected())
	assert(player.sprite.texture == player.super_form.jump)
	assert(GameHandler.player_status.powerup_form == PlayerStatus.PowerupForm.SMALL)
	for elapsed in range(56):
		GameHandler.animation_clock.tick_count += 1
		presentation._physics_process(1.0 / 60.0)
	assert(not presentation.active and player.form_controller.current_form == player.small_form)
	assert(player.sprite.texture == player.small_form.idle)
	level.free()
	await get_tree().process_frame

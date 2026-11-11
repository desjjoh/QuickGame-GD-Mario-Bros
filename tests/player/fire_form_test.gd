extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const LUIGI := preload("res://scenes/player/luigi/luigi.tscn")
const FIRE := preload("res://assets/player/forms/fire.tres")
const THEME_PALETTES := {
	"overworld": [0, 2, 3, 4],
	"underground": [0, 5, 3, 6],
	"castle": [0, 5, 3, 7],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControllerHandler.set_physics_process(false)
	GameHandler.animation_clock.set_physics_process(false)
	for theme_name: String in THEME_PALETTES:
		for is_luigi in [false, true]:
			await check_fire(is_luigi, theme_name)
	ControllerHandler.set_physics_process(true)
	GameHandler.animation_clock.set_physics_process(true)
	GameHandler.clear_session()
	print("PASS: shared Fire art, palette timing, pause, damage and character-specific Small form.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_fire(is_luigi: bool, theme_name: String) -> void:
	var level := LEVEL.instantiate() as BaseLevel
	(level.get_node("Areas/MainArea") as BaseLevelArea).theme = load(
		"res://assets/themes/%s.tres" % theme_name
	)
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
		assert(player.body.global_position == feet)
		assert(player.sprite.material == original_material)
		assert(player.state_machine.current_state == state)
		assert(presentation.active and presentation.blocks_actor_motion())
		assert(presentation.timer == (255 - elapsed if elapsed < 63 else 0))
		var palette := 0
		if player.sprite.texture != FIRE.idle:
			var frame := player.sprite.texture as AtlasTexture
			var sheet := frame.atlas.resource_path.get_file()
			assert(sheet.begins_with("palette ") and sheet.ends_with(".png"))
			palette = THEME_PALETTES[theme_name].find(int(sheet.trim_prefix("palette ")) + 1)
		assert(palette >= 0)
		var expected_slot := (
			0 if elapsed in [0, 63] else (GameHandler.animation_clock.tick_count >> 2) & 3
		)
		assert(palette == expected_slot)
		print("FIRE,%s,%s,%d,%d" % [theme_name, "luigi" if is_luigi else "mario", elapsed, palette])
		if elapsed == 2 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture := "res://.godot/validation/fire-form-%s-%s.png" % [theme_name, player.name]
			assert(get_viewport().get_texture().get_image().save_png(capture) == OK)
	GameHandler.animation_clock.tick_count += 1
	presentation._physics_process(1.0 / 60.0)
	assert(not presentation.active and not presentation.blocks_actor_motion())
	assert(level.player_presentation == null and player.sprite.material == original_material)
	assert(player.sprite.texture == FIRE.idle)
	assert(player.receive_damage() and player.damage.is_protected())
	assert(player.sprite.texture == player.super_form.jump)
	assert(GameHandler.player_status.powerup_form == PlayerStatus.PowerupForm.SMALL)
	for elapsed in range(56):
		GameHandler.animation_clock.tick_count += 1
		presentation._physics_process(1.0 / 60.0)
	assert(not presentation.active and player.form_controller.current_form == player.small_form)
	assert(player.sprite.texture == player.small_form.idle)
	player.damage.clear()
	player.form_controller.configure(player, player.super_form)
	assert(player.state_machine.change_state(player.get_node("StateMachine/Move")))
	player.animation_player.seek(player.animation_player.get_animation(&"walk").length * 0.5, true)
	var walk_index := player.super_form.walk.find(player.sprite.texture)
	assert(walk_index >= 0)
	var region := (FIRE.walk[walk_index] as AtlasTexture).region
	var offset := player.sprite.position
	assert(player.ignite())
	GameHandler.animation_clock.tick_count = 4
	presentation._physics_process(1.0 / 60.0)
	var flashing_frame := player.sprite.texture as AtlasTexture
	assert(flashing_frame.region == region and player.sprite.position == offset)
	assert(
		flashing_frame.atlas.resource_path.ends_with(
			"/palette %d.png" % (THEME_PALETTES[theme_name][1] - 1)
		)
	)
	presentation.cancel()
	var restored_frame := player.sprite.texture as AtlasTexture
	assert(
		(
			restored_frame.region == region
			and restored_frame.atlas == (FIRE.walk[0] as AtlasTexture).atlas
		)
	)
	assert(level.player_presentation == null)
	level.free()
	await get_tree().process_frame

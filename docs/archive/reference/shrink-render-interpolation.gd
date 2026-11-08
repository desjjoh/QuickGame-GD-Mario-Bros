extends Node
var level: BaseLevel
var mario: Mario
var log_file: FileAccess
var armed := false
var frames := 0
var output: String


func _ready() -> void:
	output = "res://.godot/validation/shrink-render/" + OS.get_environment("SHRINK_RENDER_CASE")
	level = load("res://scenes/levels/test_level.tscn").instantiate()
	level.player_start_configuration = MarioFormPresentation.SUPER
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	mario = level.player
	mario.set_physics_process(false)
	mario.controller_input_enabled = false
	ControllerHandler.set_physics_process(false)
	for layout in level.active_area.find_children("*", "TileMapLayer", true, false):
		layout.hide()
	for entity in level.world_objects.get_children():
		if entity is CanvasItem:
			entity.hide()
	var composer = level.get_node_or_null("Systems/ShadowComposer")
	if composer != null:
		composer.set_shadow_style(null)
	var camera = level.active_area.get_node("Camera2D")
	camera.follow_enabled = false
	camera.position = Vector2(128, 120)
	camera.force_update_scroll()
	mario.form_controller.configure(mario, MarioFormPresentation.SUPER)
	mario.body.global_position = Vector2(128, 160)
	mario.body.velocity = Vector2.ZERO
	mario.body.reset_physics_interpolation()
	if OS.get_environment("SHRINK_RENDER_CASE").begins_with("control_off"):
		mario.sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	log_file = FileAccess.open(output + ".csv", FileAccess.WRITE)
	log_file.store_line(
		"frame,clock,alpha,pose,changing,visible,offset_y,expected_bottom,rendered_bottom"
	)
	GameHandler.animation_clock.tick_count = int(OS.get_environment("SHRINK_PHASE"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(mario.receive_damage())
	armed = true
	RenderingServer.frame_post_draw.connect(_drawn)


func _drawn() -> void:
	if not armed:
		return
	var image := get_viewport().get_texture().get_image()
	var bottom := -1
	for y in range(115, 180):
		for x in range(116, 140):
			var color := image.get_pixel(x, y)
			if (
				(absf(color.r - 181.0 / 255.0) < 0.01 and absf(color.g - 49.0 / 255.0) < 0.01)
				or (absf(color.r - 107.0 / 255.0) < 0.01 and absf(color.g - 109.0 / 255.0) < 0.01)
				or (absf(color.r - 234.0 / 255.0) < 0.01 and absf(color.g - 158.0 / 255.0) < 0.01)
			):
				bottom = maxi(bottom, y)
	var art := mario.sprite.texture.get_image()
	if mario.sprite.texture is AtlasTexture:
		art = mario.sprite.texture.atlas.get_image().get_region(Rect2i(mario.sprite.texture.region))
	var art_bottom := 0
	for y in range(art.get_height()):
		for x in range(art.get_width()):
			if art.get_pixel(x, y).a > 0.5:
				art_bottom = maxi(art_bottom, y)
	var expected := (
		mario.sprite.get_global_transform_with_canvas().origin.y
		- art.get_height() * 0.5
		+ art_bottom
	)
	log_file.store_csv_line(
		[
			frames,
			GameHandler.animation_clock.tick_count,
			Engine.get_physics_interpolation_fraction(),
			mario.form_presentation.pose_index,
			mario.form_presentation.changing,
			mario.sprite.visible,
			mario.sprite.position.y,
			expected,
			bottom
		]
	)
	if mario.form_presentation.changing and frames % 2 == 0:
		image.save_png(output + "-" + str(frames) + ".png")
	frames += 1
	if not mario.form_presentation.active:
		armed = false
		log_file.close()
		print("Rendered frames: ", frames)
		await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

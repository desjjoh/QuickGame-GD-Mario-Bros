extends Node
var mario: Mario
var level: BaseLevel
var output: String
var case_name: String
var log_file: FileAccess
var event_tick := -1
var samples := 0


func _ready() -> void:
	process_physics_priority = 1000
	output = OS.get_environment("QUICKGAME_REFERENCE_OUTPUT")
	case_name = OS.get_environment("QUICKGAME_TRACE_CASE")
	var damage_case := case_name.begins_with("damage")
	var jumping := case_name.ends_with("jump")
	level = load("res://scenes/levels/test_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = (
		MarioFormPresentation.SUPER if damage_case else MarioFormPresentation.SMALL
	)
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.set_physics_process(false)
	mario = level.player as Mario
	mario.controller_input_enabled = false
	mario.body.global_position = Vector2(48, 208)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	if jumping:
		mario.body.global_position = Vector2(48, 152)
		mario.state_machine.change_state(mario.get_node("StateMachine/Jump"))
	else:
		mario.state_machine.change_state(mario.get_node("StateMachine/Move"))
	mario.body.velocity = Vector2(60 if jumping else 150, -180 if jumping else 0)
	# Align the synthetic ROM fixture's initial walk control/history too.
	mario.form_presentation._walk_frame = 0
	mario.form_presentation._walk_timer = 0
	if not jumping:
		mario.animation_player.seek(0.35 - 3.5 / 60.0, true)

	ControllerHandler.set_physics_process(false)
	ControllerHandler.input_right = 1.0
	ControllerHandler.input_secondary = true
	ControllerHandler.input_primary = jumping
	ControllerHandler.input_primary_just_pressed = false
	mario.controller_input_enabled = true
	GameHandler.animation_clock.tick_count = 215 if damage_case else 217
	if damage_case:
		var enemy := (
			load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
		)
		enemy.position = Vector2(44, 128 if jumping else 192)
		level.world_objects.add_child(enemy)
	else:
		var item := (
			load("res://scenes/entities/powerups/super_mushroom.tscn").instantiate()
			as SuperMushroom
		)
		item.position = Vector2(44, 136 if jumping else 192)
		level.world_objects.add_child(item)
	log_file = FileAccess.open(output + "/godot-" + case_name + ".csv", FileAccess.WRITE)
	log_file.store_line("relative,clock,timer,state,changing,pose,texture,visible,x,y,vx,vy")


func _physics_process(_delta: float) -> void:
	if log_file == null:
		return
	var p := mario.form_presentation
	if event_tick < 0:
		if not p.active:
			return
		event_tick = GameHandler.animation_clock.tick_count
	var relative := GameHandler.animation_clock.tick_count - event_tick
	var texture := mario.sprite.texture
	var label := texture.resource_path
	if texture == MarioFormPresentation.SMALL.idle:
		label = "Small idle"
	elif texture == MarioFormPresentation.SUPER.idle:
		label = "Super idle"
	elif texture == MarioFormPresentation.SUPER.growth_intermediate:
		label = "Intermediate"
	elif texture == MarioFormPresentation.SMALL.jump:
		label = "Small jump"
	elif texture == MarioFormPresentation.SUPER.jump:
		label = "Super jump"
	elif texture == MarioFormPresentation.SMALL.shrink_pose:
		label = "Small swim"
	elif texture == MarioFormPresentation.SUPER.shrink_pose:
		label = "Super swim"
	elif texture in MarioFormPresentation.SMALL.walk:
		label = "Small walk"
	elif texture in MarioFormPresentation.SUPER.walk:
		label = "Super walk"
	log_file.store_csv_line(
		[
			relative,
			GameHandler.animation_clock.tick_count,
			p.timer,
			mario.state_machine.current_state.name,
			p.changing,
			p.pose_index,
			label,
			mario.sprite.visible,
			mario.body.global_position.x,
			mario.body.global_position.y,
			mario.body.velocity.x,
			mario.body.velocity.y
		]
	)
	var image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	if mario.sprite.visible:
		var art := texture.get_image()
		if texture is AtlasTexture:
			art = texture.atlas.get_image().get_region(Rect2i(texture.region))
		art.convert(Image.FORMAT_RGBA8)
		if mario.sprite.flip_h:
			art.flip_x()
		image.blend_rect(
			art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(0, 32 - art.get_height())
		)
	image.save_png(output + "/godot-" + case_name + "-" + str(relative) + ".png")
	samples += 1
	if relative >= 65:
		print(case_name, " captured ", samples, " physics samples")
		log_file.close()
		log_file = null
		level.free()
		await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

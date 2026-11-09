extends Node

const LEVEL := preload("res://tests/fixtures/sandbox_level.tscn")
const STEP := 1.0 / 60.0


func _ready() -> void:
	var level := LEVEL.instantiate() as BaseLevel
	add_child(level)
	level.set_physics_process(false)
	var player := level.player as Mario
	player.set_physics_process(false)
	_check_trace(level, player, 86, 21, 735, 164604761)
	_check_trace(level, player, 74, 19, 733, 1873031776)
	_check_palettes()
	await _check_rendered_pose()
	await _check_pause(level, player)
	MusicHandler.stop_area(level)
	player.begin_death()
	assert(not player.starman.is_active() and player.starman.palette_slot == 0)
	assert(MusicHandler._voice.stream == null)
	level.queue_free()
	await get_tree().process_frame
	print("PASS: Starman Mesen duration, palette timing, music handoff, protection, and pause.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func _check_trace(
	level: BaseLevel, player: Mario, first_frame: int, phase: int, duration: int, palette_trace: int
) -> void:
	var star := player.starman
	player.damage._interval_ticks = phase
	MusicHandler.play_area(level, MusicHandler.Track.OVERWORLD)
	star.begin()
	assert(star.is_active() and star.intervals_remaining == 35 and star.palette_slot == 0)
	assert(not _is_star_music())
	var digest := 0
	for tick in range(1, duration + 1):
		GameHandler.animation_clock.tick_count = first_frame + tick
		player.damage._physics_process(STEP)
		star._physics_process(STEP)
		@warning_ignore("integer_division")
		var expected_intervals := 35 - (tick + 21 - phase) / 21
		assert(star.intervals_remaining == expected_intervals)
		assert(star.is_active() == (tick < duration))
		assert(_is_star_music() == (tick < duration - 63))
		if star.is_active():
			assert(not player.receive_damage())
		digest = (31 * digest + star.palette_slot) % 2147483647
	assert(MusicHandler._voice.stream == MusicHandler._loops[MusicHandler.Track.OVERWORLD])
	# Digest of the captured OAM palette slots from pickup+1 through expiry.
	assert(digest == palette_trace, "Rendered palette slot cadence differs from the Mesen trace.")
	star._physics_process(STEP)
	assert(star.palette_slot == 0)


func _check_palettes() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cases := [
		[
			preload("res://assets/themes/overworld.tres"),
			preload("res://assets/player/mario (small)/mario-small-idle.png"),
			Color("b53120"),
			Color("109400")
		],
		[
			preload("res://assets/themes/underground.tres"),
			preload("res://assets/player/luigi (super)/luigi-idle.png"),
			Color.WHITE,
			Color("007b8c")
		],
		[
			preload("res://assets/themes/castle.tres"),
			preload("res://assets/player/mario + luigi (fire)/shoot.png"),
			Color("f7d8a5"),
			Color("007b8c")
		]
	]
	for item: Array in cases:
		var theme := item[0] as AreaTheme
		var source := item[1] as Texture2D
		var recolored := theme.fire_transform_palettes[0].remap_starman(source)
		assert(recolored.get_size() == source.get_size())
		assert(recolored == theme.fire_transform_palettes[0].remap_starman(source))
		var original := source.get_image()
		var result := recolored.get_image()
		var changed := false
		for y in range(original.get_height()):
			for x in range(original.get_width()):
				var pixel := original.get_pixel(x, y)
				var replacement := result.get_pixel(x, y)
				assert(pixel.a == replacement.a)
				if pixel.to_rgba32() == (item[2] as Color).to_rgba32():
					assert(
						replacement.to_rgba32() == (item[3] as Color).to_rgba32(),
						"%s recolored to %s, expected %s." % [source.resource_path, replacement, item[3]]
					)
					changed = true
		assert(changed)


func _check_rendered_pose() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.position = Vector2(16, 16)
	sprite.texture = preload("res://assets/player/mario (small)/mario-small-idle.png")
	viewport.add_child(sprite)
	var pose := FireThrowPose.new()
	pose.hide()
	sprite.add_child(pose)
	var theme := preload("res://assets/themes/overworld.tres") as AreaTheme
	var palette := theme.fire_transform_palettes[0]
	pose.set_palette(palette)
	await RenderingServer.frame_post_draw
	_assert_pixels(viewport, palette.remap_starman(sprite.texture), Rect2i(8, 8, 16, 16))
	var fire := AtlasTexture.new()
	fire.atlas = preload("res://assets/player/mario + luigi (fire)/idle.png")
	fire.region = Rect2(0, 0, 16, 32)
	sprite.texture = fire
	pose.update_pose(7, false, false)
	await RenderingServer.frame_post_draw
	_assert_pixels(viewport, palette.remap_starman(FireThrowPose.SHEET), Rect2i(8, 0, 16, 32))
	pose.clear()
	pose.set_palette(null)
	await RenderingServer.frame_post_draw
	_assert_pixels(viewport, fire.atlas, Rect2i(8, 0, 16, 32))
	viewport.queue_free()


func _assert_pixels(viewport: SubViewport, expected: Texture2D, rect: Rect2i) -> void:
	var render := viewport.get_texture().get_image()
	var source := expected.get_image()
	for y in range(rect.size.y):
		for x in range(rect.size.x):
			var pixel := source.get_pixel(x, y)
			var actual := render.get_pixelv(rect.position + Vector2i(x, y))
			assert(actual.a == pixel.a)
			if pixel.a > 0.0:
				assert(actual.to_rgba32() == pixel.to_rgba32())


func _check_pause(level: BaseLevel, player: Mario) -> void:
	MusicHandler.play_area(level, MusicHandler.Track.OVERWORLD)
	player.starman.begin()
	await get_tree().physics_frame
	await get_tree().process_frame
	assert(_is_star_music() and MusicHandler._voice.playing)
	# Same-level area music selection changes while the override is active.
	MusicHandler.play_area(level, MusicHandler.Track.UNDERGROUND, true)
	assert(_is_star_music())
	get_tree().paused = true
	var intervals := player.starman.intervals_remaining
	var phase := player.damage._interval_ticks
	var palette := player.starman.palette_slot
	for tick in range(30):
		await get_tree().physics_frame
	assert(player.starman.intervals_remaining == intervals)
	assert(player.damage._interval_ticks == phase and player.starman.palette_slot == palette)
	assert(_is_star_music() and MusicHandler._voice.stream_paused)
	get_tree().paused = false
	await get_tree().physics_frame
	await get_tree().process_frame
	assert(player.damage._interval_ticks != phase and not MusicHandler._voice.stream_paused)
	player.starman.clear()
	assert(MusicHandler._voice.stream == MusicHandler._loops[MusicHandler.Track.UNDERGROUND])
	player.starman.begin()
	player.starman.intervals_remaining = 4
	player.starman.begin()
	assert(player.starman.intervals_remaining == 35)


func _is_star_music() -> bool:
	return MusicHandler._voice.stream == MusicHandler._loops[MusicHandler.STARMAN_TRACK]

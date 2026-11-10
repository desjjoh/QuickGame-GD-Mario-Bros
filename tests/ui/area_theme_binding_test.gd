extends Node

const BINDING := preload("res://scripts/themes/area_theme_binding.gd")
var received: Array[AreaTheme] = []


func _ready() -> void:
	assert(GameHandler.current_level == null)
	var level_connections := GameHandler.level_changed.get_connections().size()
	var session_connections := GameHandler.session_value_changed.get_connections().size()
	var binding := BINDING.new()
	add_child(binding)
	binding.theme_changed.connect(func(theme: AreaTheme): received.append(theme))
	binding.start()
	assert(received.size() == 1 and received.back() == null)
	binding.start()
	assert(received.size() == 1, "Starting twice must not duplicate subscriptions")
	var hud := preload("res://scenes/ui/hud/hud.tscn").instantiate()
	var title := preload("res://scenes/ui/title/title_screen.tscn").instantiate()
	add_child(hud)
	add_child(title)
	var coin := hud.get_node("Coin") as AnimatedSprite2D
	coin.frame = 2
	coin.frame_progress = 0.35
	var default_coin := (coin.sprite_frames.get_frame_texture(&"default", 0) as AtlasTexture).atlas
	var default_card: Texture2D = title.get_node("TitleCard").texture
	var default_font: Font = title.get_node("Copyright").get_theme_font(&"font")
	# Lightweight owners exercise the notification contract without starting gameplay.
	var first := BaseLevel.new()
	var area := BaseLevelArea.new()
	first.active_area = area
	GameHandler.current_level = first
	var custom := AreaTheme.new()
	var replacement := ImageTexture.create_from_image(
		Image.create(16, 16, false, Image.FORMAT_RGBA8)
	)
	custom.texture_overrides[default_coin.resource_path] = replacement
	custom.texture_overrides[default_card.resource_path] = replacement
	custom.title_accent_font = preload("res://assets/ui/fonts/hud.fnt")
	area.theme = custom
	GameHandler.level_changed.emit(first)
	assert(received.back() == custom)
	assert(
		(coin.sprite_frames.get_frame_texture(&"default", 0) as AtlasTexture).atlas == replacement
	)
	assert(title.get_node("TitleCard").texture == replacement)
	assert(title.get_node("Copyright").get_theme_font(&"font") == custom.title_accent_font)
	assert(coin.frame == 2 and is_equal_approx(coin.frame_progress, 0.35))
	GameHandler.session_value_changed.emit(&"current_area_id", &"same")
	GameHandler.level_changed.emit(first)
	assert(area.area_theme_changed.get_connections().size() == 3)
	var before := received.size()
	area.theme = null
	area.area_theme_changed.emit(null)
	assert(received.size() == before + 1 and received.back() == null)
	assert(
		(coin.sprite_frames.get_frame_texture(&"default", 0) as AtlasTexture).atlas == default_coin
	)
	assert(title.get_node("TitleCard").texture == default_card)
	assert(title.get_node("Copyright").get_theme_font(&"font") == default_font)
	var next := BaseLevelArea.new()
	first.active_area = next
	GameHandler.session_value_changed.emit(&"current_area_id", &"next")
	assert(area.area_theme_changed.get_connections().is_empty())
	before = received.size()
	area.area_theme_changed.emit(custom)
	assert(received.size() == before, "Old areas must no longer update UI")
	area.free()
	var second := BaseLevel.new()
	second.active_area = next
	GameHandler.current_level = second
	first.free()
	GameHandler.level_changed.emit(second)
	assert(next.area_theme_changed.get_connections().size() == 3)
	hud.free()
	title.free()
	binding.free()
	assert(next.area_theme_changed.get_connections().is_empty())
	assert(GameHandler.level_changed.get_connections().size() == level_connections)
	assert(GameHandler.session_value_changed.get_connections().size() == session_connections)
	GameHandler.current_level = null
	next.free()
	second.free()
	print("area_theme_binding_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

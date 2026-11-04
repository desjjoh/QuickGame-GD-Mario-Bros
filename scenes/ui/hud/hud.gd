extends Control
## Persistent HUD artwork follows the active area without restarting its clock.

const DEFAULT_COIN = preload("res://assets/palettes/overworld/ui/hud-coin.png")

var _theme_area: BaseLevelArea

@onready var coin: AnimatedSprite2D = $Coin


func _ready() -> void:
	coin.sprite_frames = coin.sprite_frames.duplicate(true)
	GameHandler.level_changed.connect(_on_level_changed)
	GameHandler.session_value_changed.connect(_on_session_value_changed)
	_bind_area_theme()
	_refresh_values()


func _on_level_changed(_level: BaseLevel) -> void:
	_bind_area_theme()


func _on_session_value_changed(key: StringName, _value: Variant) -> void:
	if key == &"current_area_id":
		_bind_area_theme()
	if key in [&"score", &"coins", &"stage_label", &"time_remaining"]:
		_refresh_values()


func _refresh_values() -> void:
	$Score.text = " %06d" % GameHandler.player_status.score
	$CoinCount.text = "%02d" % GameHandler.player_status.coins
	$WorldValue.text = GameHandler.stage_label
	$TimeValue.text = "%03d" % GameHandler.time_remaining


func _bind_area_theme() -> void:
	if (
		is_instance_valid(_theme_area)
		and _theme_area.area_theme_changed.is_connected(_on_area_theme_changed)
	):
		_theme_area.area_theme_changed.disconnect(_on_area_theme_changed)

	_theme_area = null
	var level := GameHandler.current_level
	if is_instance_valid(level) and is_instance_valid(level.active_area):
		_theme_area = level.active_area
		_theme_area.area_theme_changed.connect(_on_area_theme_changed)

	_refresh_theme()


func _on_area_theme_changed(_theme: AreaTheme) -> void:
	_refresh_theme()


func _refresh_theme() -> void:
	var texture: Texture2D = DEFAULT_COIN
	var level := GameHandler.current_level
	if (
		is_instance_valid(level)
		and is_instance_valid(level.active_area)
		and level.active_area.theme != null
	):
		texture = level.active_area.theme.resolve_texture(DEFAULT_COIN)
	# Changing atlas artwork preserves the selected shared-clock frame.
	for index in range(coin.sprite_frames.get_frame_count(&"default")):
		var atlas := coin.sprite_frames.get_frame_texture(&"default", index) as AtlasTexture
		atlas.atlas = texture


func _exit_tree() -> void:
	if (
		is_instance_valid(_theme_area)
		and _theme_area.area_theme_changed.is_connected(_on_area_theme_changed)
	):
		_theme_area.area_theme_changed.disconnect(_on_area_theme_changed)
	if GameHandler.level_changed.is_connected(_on_level_changed):
		GameHandler.level_changed.disconnect(_on_level_changed)
	if GameHandler.session_value_changed.is_connected(_on_session_value_changed):
		GameHandler.session_value_changed.disconnect(_on_session_value_changed)

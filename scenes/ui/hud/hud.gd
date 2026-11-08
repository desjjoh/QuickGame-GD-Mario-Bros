extends Control
## Persistent HUD artwork follows the active area without restarting its clock.

const DEFAULT_COIN = preload("res://assets/palettes/overworld/ui/hud-coin.png")

const THEME_BINDING := preload("res://scripts/themes/area_theme_binding.gd")
@onready var theme_binding: THEME_BINDING = $AreaThemeBinding

@onready var coin: AnimatedSprite2D = $Coin


func _ready() -> void:
	coin.sprite_frames = coin.sprite_frames.duplicate(true)
	GameHandler.session_value_changed.connect(_on_session_value_changed)
	theme_binding.theme_changed.connect(_apply_area_theme)
	theme_binding.start()
	_refresh_values()


func _on_session_value_changed(key: StringName, _value: Variant) -> void:
	if key in [&"score", &"coins", &"stage_label", &"time_remaining", &"timer_enabled"]:
		_refresh_values()


func _refresh_values() -> void:
	$Score.text = " %06d" % GameHandler.player_status.score
	$CoinCount.text = "%02d" % GameHandler.player_status.coins
	$WorldValue.text = GameHandler.stage_label.left(3)
	$TimeValue.text = "%03d" % GameHandler.time_remaining
	$TimeValue.visible = GameHandler.timer_enabled


func _apply_area_theme(area_theme: AreaTheme) -> void:
	var texture: Texture2D = DEFAULT_COIN
	if area_theme != null:
		texture = area_theme.resolve_texture(DEFAULT_COIN)
	# Changing atlas artwork preserves the selected shared-clock frame.
	for index in range(coin.sprite_frames.get_frame_count(&"default")):
		var atlas := coin.sprite_frames.get_frame_texture(&"default", index) as AtlasTexture
		atlas.atlas = texture


func _exit_tree() -> void:
	if GameHandler.session_value_changed.is_connected(_on_session_value_changed):
		GameHandler.session_value_changed.disconnect(_on_session_value_changed)

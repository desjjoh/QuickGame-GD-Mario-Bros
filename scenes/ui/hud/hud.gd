extends Control
## Persistent HUD artwork follows the active area without restarting its clock.
const DEFAULT_COIN = preload("res://assets/Overworld (Palette 1)/ui/hud-coin.png")
@onready var coin: AnimatedSprite2D = $Coin

func _ready() -> void:
 coin.sprite_frames = coin.sprite_frames.duplicate(true)
 GameHandler.level_changed.connect(_on_level_changed)
 GameHandler.session_value_changed.connect(_on_session_value_changed)
 _refresh_theme()

func _on_level_changed(_level: BaseLevel) -> void:
 _refresh_theme()

func _on_session_value_changed(key: StringName, _value: Variant) -> void:
 if key == &"current_area_id": _refresh_theme()

func _refresh_theme() -> void:
 var texture: Texture2D = DEFAULT_COIN
 var level := GameHandler.current_level
 if is_instance_valid(level) and is_instance_valid(level.active_area) and level.active_area.theme != null:
  texture = level.active_area.theme.resolve_texture(DEFAULT_COIN)
 for index in range(coin.sprite_frames.get_frame_count(&"default")):
  var atlas := coin.sprite_frames.get_frame_texture(&"default",index) as AtlasTexture
  atlas.atlas = texture
 # Changing atlas artwork preserves the selected shared-clock frame.

func _exit_tree() -> void:
 if GameHandler.level_changed.is_connected(_on_level_changed):
  GameHandler.level_changed.disconnect(_on_level_changed)
 if GameHandler.session_value_changed.is_connected(_on_session_value_changed):
  GameHandler.session_value_changed.disconnect(_on_session_value_changed)

class_name AreaThemeBinding
extends Node
## Event-driven active-area subscription. Screens own artwork and fallback assets.

signal theme_changed(theme: AreaTheme)

var _started := false
var _area: BaseLevelArea


## Start from the parent's _ready(), after its presentation references are ready.
func start() -> void:
	if _started:
		return
	_started = true
	GameHandler.level_changed.connect(_on_level_changed)
	GameHandler.session_value_changed.connect(_on_session_value_changed)
	_bind_area()


func _on_level_changed(_level: BaseLevel) -> void:
	_bind_area()


func _on_session_value_changed(key: StringName, _value: Variant) -> void:
	if key == &"current_area_id":
		_bind_area()


func _bind_area() -> void:
	var next_area: BaseLevelArea
	var level := GameHandler.current_level
	if is_instance_valid(level) and is_instance_valid(level.active_area):
		next_area = level.active_area
	if _area != next_area:
		_disconnect_area()
		_area = next_area
		if is_instance_valid(_area):
			_area.area_theme_changed.connect(_on_area_theme_changed)
	theme_changed.emit(_area.theme if is_instance_valid(_area) else null)


func _on_area_theme_changed(theme: AreaTheme) -> void:
	theme_changed.emit(theme)


func _disconnect_area() -> void:
	if is_instance_valid(_area) and _area.area_theme_changed.is_connected(_on_area_theme_changed):
		_area.area_theme_changed.disconnect(_on_area_theme_changed)
	_area = null


func _exit_tree() -> void:
	_disconnect_area()
	if _started:
		GameHandler.level_changed.disconnect(_on_level_changed)
		GameHandler.session_value_changed.disconnect(_on_session_value_changed)
	_started = false

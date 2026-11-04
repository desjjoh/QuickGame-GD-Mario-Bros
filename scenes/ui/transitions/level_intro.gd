extends Control
## Snapshot on creation plus event-driven refresh during the loading presentation.
func _ready() -> void:
	GameHandler.session_value_changed.connect(_on_session_value_changed)
	_refresh_values()

func _on_session_value_changed(key: StringName, _value: Variant) -> void:
	if key in [&"lives", &"stage_label"]: _refresh_values()

func _refresh_values() -> void:
	$World.text = "WORLD %s" % GameHandler.stage_label
	$Lives.text = "× %d" % GameHandler.player_status.lives

func _exit_tree() -> void:
	if GameHandler.session_value_changed.is_connected(_on_session_value_changed):
		GameHandler.session_value_changed.disconnect(_on_session_value_changed)

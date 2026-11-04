extends Control
## Persistent title UI. GameHandler owns its background and game-flow decisions.

const DEFAULT_CURSOR = preload("res://assets/palettes/overworld/ui/start-cursor.png")
const DEFAULT_TITLE_CARD = preload("res://assets/palettes/overworld/ui/start-title.png")
const DEFAULT_ACCENT_FONT = preload("res://assets/palettes/overworld/ui/alphabet-alt.fnt")
var _theme_area: BaseLevelArea

@onready var title_card: Sprite2D = $TitleCard
@onready var cursor: Sprite2D = $Cursor

signal start_requested
@export var background_level: PackedScene


func _ready() -> void:
	process_physics_priority = -90
	GameHandler.level_changed.connect(_on_level_changed)
	GameHandler.session_value_changed.connect(_on_session_value_changed)
	_bind_area_theme()
	_refresh_top_score()


func _physics_process(_delta: float) -> void:
	if (
		is_visible_in_tree()
		and ControllerHandler.enabled
		and ControllerHandler.input_start_just_pressed
	):
		start_requested.emit()


func _on_level_changed(_level: BaseLevel) -> void:
	_bind_area_theme()


func _on_session_value_changed(key: StringName, _value: Variant) -> void:
	if key == &"current_area_id":
		_bind_area_theme()
	if key == &"top_score":
		_refresh_top_score()


func _refresh_top_score() -> void:
	$TopScore.text = "TOP- %06d" % GameHandler.top_score


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
	title_card.texture = (
		_theme_area.theme.resolve_texture(DEFAULT_TITLE_CARD)
		if is_instance_valid(_theme_area) and _theme_area.theme != null
		else DEFAULT_TITLE_CARD
	)
	var accent_font: Font = DEFAULT_ACCENT_FONT
	if (
		is_instance_valid(_theme_area)
		and _theme_area.theme != null
		and _theme_area.theme.title_accent_font != null
	):
		accent_font = _theme_area.theme.title_accent_font
	$Copyright.add_theme_font_override(&"font", accent_font)
	cursor.texture = (
		_theme_area.theme.resolve_texture(DEFAULT_CURSOR)
		if is_instance_valid(_theme_area) and _theme_area.theme != null
		else DEFAULT_CURSOR
	)


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

extends Control
## Persistent title UI. GameHandler owns its background and game-flow decisions.

const DEFAULT_CURSOR = preload("res://assets/palettes/overworld/ui/start-cursor.png")
const DEFAULT_TITLE_CARD = preload("res://assets/palettes/overworld/ui/start-title.png")
const DEFAULT_ACCENT_FONT = preload("res://assets/palettes/overworld/ui/alphabet-alt.fnt")
const THEME_BINDING := preload("res://scripts/themes/area_theme_binding.gd")
@onready var theme_binding: THEME_BINDING = $AreaThemeBinding

@onready var title_card: Sprite2D = $TitleCard
@onready var cursor: Sprite2D = $Cursor

signal start_requested(level: PackedScene)


func _ready() -> void:
	process_physics_priority = -90
	GameHandler.session_value_changed.connect(_on_session_value_changed)
	theme_binding.theme_changed.connect(_apply_area_theme)
	theme_binding.start()
	_refresh_top_score()


func _physics_process(_delta: float) -> void:
	if not is_visible_in_tree() or not ControllerHandler.enabled:
		return
	if ControllerHandler.input_start_just_pressed:
		start_requested.emit(null)


func _on_session_value_changed(key: StringName, _value: Variant) -> void:
	if key == &"top_score":
		_refresh_top_score()


func _refresh_top_score() -> void:
	$TopScore.text = "TOP- %06d" % GameHandler.top_score


func _apply_area_theme(area_theme: AreaTheme) -> void:
	title_card.texture = (
		area_theme.resolve_texture(DEFAULT_TITLE_CARD) if area_theme != null else DEFAULT_TITLE_CARD
	)
	var accent_font: Font = DEFAULT_ACCENT_FONT
	if area_theme != null and area_theme.title_accent_font != null:
		accent_font = area_theme.title_accent_font
	$Copyright.add_theme_font_override(&"font", accent_font)
	cursor.texture = (
		area_theme.resolve_texture(DEFAULT_CURSOR) if area_theme != null else DEFAULT_CURSOR
	)


func _exit_tree() -> void:
	if GameHandler.session_value_changed.is_connected(_on_session_value_changed):
		GameHandler.session_value_changed.disconnect(_on_session_value_changed)

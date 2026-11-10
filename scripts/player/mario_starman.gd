class_name MarioStarman
extends Node
## Player protection, driven by the same interval cadence as injury protection.

const START_INTERVALS := 35
const MUSIC_RETURN_INTERVAL := 3
const OVERWORLD := preload("res://assets/themes/overworld.tres")

var intervals_remaining := 0
var palette_slot := 0
var _music_pending := false
var _palette_intervals := 0
var _mario: Mario
var _level: BaseLevel
var _pose: FireThrowPose


func _ready() -> void:
	_mario = get_node("../..") as Mario
	_level = BaseLevel.containing(self)
	_pose = _mario.get_node("Body/Sprite2D/ThrowPose") as FireThrowPose
	var damage := get_node("../Damage") as MarioDamage
	damage.interval_elapsed.connect(_on_interval_elapsed)
	process_physics_priority = -69


func is_active() -> bool:
	return intervals_remaining > 0


func uses_starman_music() -> bool:
	return intervals_remaining > MUSIC_RETURN_INTERVAL and not _music_pending


func begin() -> void:
	intervals_remaining = START_INTERVALS
	_palette_intervals = START_INTERVALS
	_music_pending = true


func clear() -> void:
	intervals_remaining = 0
	_music_pending = false
	_palette_intervals = 0
	_set_palette(0)
	MusicHandler.end_starman(_level)


func _physics_process(_delta: float) -> void:
	if _music_pending:
		_music_pending = false
		MusicHandler.play_starman(_level)
	if _mario.form_presentation.owns_palette():
		_set_palette(0)
	elif _palette_intervals > 0 and not _mario.gameplay_suspended:
		# The visible palette uses the count from before this update's interval step.
		var shift := 3 if _palette_intervals <= 7 else 1
		_set_palette(((GameHandler.animation_clock.tick_count - 1) >> shift) & 3)
	elif not is_active() and palette_slot != 0:
		_set_palette(0)
	_palette_intervals = intervals_remaining


func _on_interval_elapsed() -> void:
	if not is_active():
		return
	intervals_remaining -= 1
	if intervals_remaining == MUSIC_RETURN_INTERVAL:
		MusicHandler.end_starman(_level)


func _set_palette(slot: int) -> void:
	palette_slot = slot
	var palette: PlayerPalette
	if slot != 0:
		var theme: AreaTheme
		if is_instance_valid(_level) and is_instance_valid(_level.active_area):
			theme = _level.active_area.theme
		if theme == null or theme.fire_transform_palettes.size() < slot:
			theme = OVERWORLD
		palette = theme.fire_transform_palettes[slot - 1]
	_pose.set_palette(palette)

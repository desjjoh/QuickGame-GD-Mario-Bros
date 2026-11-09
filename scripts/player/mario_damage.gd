class_name MarioDamage
extends Node
## Injury protection is independent of form art and the shrinking presentation.

signal interval_elapsed

const INTERVAL_TICKS := 21
const INJURY_INTERVALS := 8

var intervals_remaining := 0
var _interval_ticks := INTERVAL_TICKS
var _visible := true
var _mario: Mario


func _ready() -> void:
	_mario = get_node("../..") as Mario
	process_physics_priority = -70  # After form presentation, before enemy contact.


func is_protected() -> bool:
	return intervals_remaining > 0


func begin() -> void:
	_visible = _mario.sprite.visible
	intervals_remaining = INJURY_INTERVALS
	apply_visibility()


func _physics_process(_delta: float) -> void:
	if _mario.is_dead or _mario.is_shutdown:
		clear()
		return
	# Match the interval timer's pause under the transformation master timer.
	# Keep this cadence running before injury so the first decrement is phase-dependent.
	if not _mario.gameplay_suspended and not _mario.form_presentation.active:
		_interval_ticks -= 1
		if _interval_ticks == 0:
			_interval_ticks = INTERVAL_TICKS
			if is_protected():
				intervals_remaining -= 1
				if not is_protected():
					_mario.sprite.visible = _visible
			interval_elapsed.emit()
	apply_visibility()


func apply_visibility() -> void:
	if is_protected():
		_mario.sprite.visible = _visible and GameHandler.animation_clock.tick_count % 2 == 0


func clear() -> void:
	if is_protected() and is_instance_valid(_mario):
		_mario.sprite.visible = _visible
	intervals_remaining = 0

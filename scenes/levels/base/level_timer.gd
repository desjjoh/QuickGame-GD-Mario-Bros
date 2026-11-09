class_name LevelTimer
extends Node
## Advances only when the owning level permits gameplay ticks.

signal expired
signal hurry_started

const TICKS_PER_UNIT := 24
const HURRY_THRESHOLD := 100

var ticks_remaining: int = TICKS_PER_UNIT
var has_expired := false
var is_hurry := false
var _last_tick := -1


func start(tick: int, timer_enabled: bool = true) -> void:
	ticks_remaining = TICKS_PER_UNIT
	_last_tick = tick
	has_expired = false
	var time := GameHandler.time_remaining
	is_hurry = timer_enabled and time > 0 and time < HURRY_THRESHOLD


func advance(tick: int) -> void:
	if has_expired or tick == _last_tick:
		return
	_last_tick = tick
	ticks_remaining -= 1
	if ticks_remaining > 0:
		return
	ticks_remaining = TICKS_PER_UNIT
	if GameHandler.time_remaining == 0:
		has_expired = true
		expired.emit()
	else:
		var starts_hurry := not is_hurry and GameHandler.time_remaining == HURRY_THRESHOLD
		is_hurry = is_hurry or starts_hurry
		GameHandler.time_remaining -= 1
		if starts_hurry:
			hurry_started.emit()

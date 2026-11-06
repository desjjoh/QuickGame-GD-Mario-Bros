class_name LevelTimer
extends Node
## Advances only when the owning level permits gameplay ticks.

signal expired

const TICKS_PER_UNIT := 24

var ticks_remaining: int = TICKS_PER_UNIT
var has_expired := false
var _last_tick := -1


func start(tick: int) -> void:
	ticks_remaining = TICKS_PER_UNIT
	_last_tick = tick
	has_expired = false


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
		GameHandler.time_remaining -= 1

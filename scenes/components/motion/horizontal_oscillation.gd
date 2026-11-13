@tool
extends RefCounted
## NES horizontal platform and flying Parakoopa counter motion.

var position_fraction := 0
var _phase := 0
var _speed := 0
var _maximum_speed: int


func _init(maximum_speed: int) -> void:
	_maximum_speed = maximum_speed


func step(frame: int) -> int:
	if frame % 4 == 0:
		var slowing := (_phase & 1) != 0
		var limit := 0 if slowing else _maximum_speed
		if _speed == limit:
			_phase = (_phase + 1) % 4
		else:
			_speed += -1 if slowing else 1
	var direction := -1 if _phase < 2 else 1
	var accumulated := position_fraction + direction * _speed * 16
	position_fraction = posmod(accumulated, 256)
	return accumulated >> 8

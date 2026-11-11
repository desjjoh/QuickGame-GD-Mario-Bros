extends RefCounted
## NES vertical platform and Red Parakoopa movement in 1/256-pixel units.

var position_fraction := 0
var speed := 0
var _downward_force: int
var _upward_force: int
var _maximum_speed: int


func _init(downward_force: int, upward_force: int, maximum_speed: int) -> void:
	_downward_force = downward_force
	_upward_force = upward_force
	_maximum_speed = maximum_speed * 256


func step(y: int, top_y: int, center_y: int, frame: int) -> int:
	if speed == 0:
		position_fraction = 0
		if y < top_y:
			return 1 if frame % 8 == 0 else 0
	var accumulated := position_fraction + speed
	position_fraction = posmod(accumulated, 256)
	speed += _downward_force
	if speed >= _maximum_speed + 128:
		speed = _maximum_speed
	if y >= center_y:
		speed -= _upward_force
		# The reference clamps the integer byte and writes $ff to the fraction.
		if speed < -_maximum_speed and posmod(speed, 256) < 128:
			speed = -_maximum_speed + 255
	return accumulated >> 8

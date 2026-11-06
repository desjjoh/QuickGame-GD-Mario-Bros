class_name CastleEntity
extends BaseEntity
## The ending presentation advances the flag once per physics tick.

const FLAG_RISE_PIXELS := 31

@onready var doorway: Marker2D = $Doorway
@onready var _flag: Sprite2D = $Flag
@onready var _flag_start_y: float = _flag.position.y


func raise_flag() -> void:
	reset_flag()
	_flag.show()


func advance_flag_raise() -> bool:
	if _flag.position.y <= _flag_start_y - FLAG_RISE_PIXELS:
		return true
	_flag.position.y -= 1.0
	return false


func reset_flag() -> void:
	_flag.hide()
	_flag.position.y = _flag_start_y

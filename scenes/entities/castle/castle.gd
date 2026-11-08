class_name CastleEntity
extends BaseEntity
## The ending presentation advances the flag once per physics tick.

const FLAG_RISE_PIXELS := 31
const BURST_INTERVAL := 32
const BURST_DURATION := 24
const BURST_POSITIONS := [
	Vector2(-48, -112),
	Vector2(0, -144),
	Vector2(48, -96),
	Vector2(48, -144),
	Vector2(-48, -112),
	Vector2(-16, -160)
]

signal firework_finished
var fireworks_active := false
var _burst_count := 0
var _burst_index := 0
var _fireworks_tick := 0
@onready var _firework: Sprite2D = $Presentation/Fireworks/Burst

@onready var doorway: Marker2D = $Anchors/Doorway
@onready var _flag: Sprite2D = $Presentation/Flag
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


func begin_fireworks(count: int) -> void:
	cancel_fireworks()
	_burst_count = count if count in [1, 3, 6] else 0
	fireworks_active = _burst_count > 0
	if fireworks_active:
		_show_burst()


func _show_burst() -> void:
	# The NES indexes backwards; 1 and 3 use the last 1/3 positions.
	var offset: Vector2 = BURST_POSITIONS[5 - _burst_index]
	_firework.position = Vector2(_flag.position.x, doorway.position.y) + offset - Vector2(4, 4)
	_firework.frame = 0
	_firework.show()


## Driven by the ending step, like advance_flag_raise(). True means complete.
func advance_fireworks() -> bool:
	if not fireworks_active:
		return true
	_fireworks_tick += 1
	var age := _fireworks_tick % BURST_INTERVAL
	if age == BURST_DURATION:
		_firework.hide()
		_burst_index += 1
		var done := _burst_index == _burst_count
		if done:
			fireworks_active = false
		firework_finished.emit()
		return done
	if age == 0:
		_show_burst()
	elif age < BURST_DURATION:
		_firework.frame = floori(age / 8.0)
	return false


func cancel_fireworks() -> void:
	fireworks_active = false
	_burst_count = 0
	_burst_index = 0
	_fireworks_tick = 0
	if is_instance_valid(_firework):
		_firework.hide()


func shutdown() -> void:
	cancel_fireworks()
	super.shutdown()

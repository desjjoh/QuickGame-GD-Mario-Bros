class_name PlayerStatus
extends Resource
## GameHandler owns this record; UI and spawned players do not copy it.
enum PowerupForm { SMALL, SUPER, FIRE }
signal changed_value(key: StringName, value: int)

var score: int = 0:
	set(value):
		value = clampi(value, 0, 999999)
		if score == value: return
		score = value
		changed_value.emit(&"score", score)
var coins: int = 0:
	set(value):
		value = clampi(value, 0, 99)
		if coins == value: return
		coins = value
		changed_value.emit(&"coins", coins)
var lives: int = 3:
	set(value):
		value = clampi(value, 0, 99)
		if lives == value: return
		lives = value
		changed_value.emit(&"lives", lives)
var powerup_form: PowerupForm = PowerupForm.SMALL:
	set(value):
		if value not in [PowerupForm.SMALL, PowerupForm.SUPER, PowerupForm.FIRE]: return
		if powerup_form == value: return
		powerup_form = value
		changed_value.emit(&"powerup_form", powerup_form)

func reset() -> void:
	score = 0
	coins = 0
	lives = 3
	powerup_form = PowerupForm.SMALL

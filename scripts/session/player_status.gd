class_name PlayerStatus
extends Resource
## GameHandler owns this record; UI and spawned players do not copy it.

enum PowerupForm { SMALL, SUPER, FIRE }

const DEFAULT_SCORE: int = 0
const DEFAULT_COINS: int = 0
const DEFAULT_LIVES: int = 2
const DEFAULT_POWERUP_FORM: PowerupForm = PowerupForm.SMALL

signal changed_value(key: StringName, value: int)

var score: int = DEFAULT_SCORE:
	set(value):
		value = clampi(value, 0, 999999)
		if score == value:
			return
		score = value
		changed_value.emit(&"score", score)

var coins: int = DEFAULT_COINS:
	set(value):
		value = clampi(value, 0, 99)
		if coins == value:
			return
		coins = value
		changed_value.emit(&"coins", coins)

## Reserve counter: 2 displays three attempts; -1 means exhausted.
var lives: int = DEFAULT_LIVES:
	set(value):
		value = clampi(value, -1, 98)
		if lives == value:
			return
		lives = value
		changed_value.emit(&"lives", lives)

var powerup_form: PowerupForm = DEFAULT_POWERUP_FORM:
	set(value):
		if value not in [PowerupForm.SMALL, PowerupForm.SUPER, PowerupForm.FIRE]:
			return
		if powerup_form == value:
			return
		powerup_form = value
		changed_value.emit(&"powerup_form", powerup_form)


func get_display_lives() -> int:
	return maxi(lives + 1, 0)


func reset(
	starting_score: int = DEFAULT_SCORE,
	starting_coins: int = DEFAULT_COINS,
	starting_reserves: int = DEFAULT_LIVES
) -> void:
	score = starting_score
	coins = starting_coins
	lives = starting_reserves
	powerup_form = DEFAULT_POWERUP_FORM

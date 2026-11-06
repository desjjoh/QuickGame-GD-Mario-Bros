extends Sprite2D
## Transient world-space presentation for a coin already awarded by a block.

const TEXTURE := preload("res://assets/items/block-coin.png")
const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")
const INITIAL_SPEED := -300.0
const GRAVITY := 1125.0
const END_SPEED := 300.0
const FRAME_DURATION := 2.0 / 60.0
const POPUP_DURATION := 46.0 / 60.0
const POPUP_SPEED := 30.0

var _speed := INITIAL_SPEED
var _elapsed := 0.0
var _popup: Sprite2D


func _ready() -> void:
	texture = TEXTURE
	hframes = 4


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _popup != null:
		_popup.position.y -= POPUP_SPEED * delta
		if _elapsed >= POPUP_DURATION:
			queue_free()
		return

	position.y += _speed * delta
	_speed += GRAVITY * delta
	frame = floori(_elapsed / FRAME_DURATION) % hframes
	if _speed >= END_SPEED:
		texture = null
		_elapsed = 0.0
		_popup = SCORE_POPUP.instantiate()
		add_child(_popup)
		_popup.show_score(200, global_position)

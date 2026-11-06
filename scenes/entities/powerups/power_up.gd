class_name PowerUp
extends SpawnableEntity
## An available power-up accepts one valid player contact.

const EMERGENCE_HEIGHT := 16.0
const EMERGENCE_STEP_TIME := 4.0 / 60.0

var _removing := false
var _emergence_remaining := 0.0
var _emergence_elapsed := 0.0
var _previous_interpolation_mode: PhysicsInterpolationMode

@export var pickup: Area2D


func _ready() -> void:
	pickup.monitoring = is_zero_approx(_emergence_remaining)
	super()
	if _emergence_remaining > 0.0:
		sprite.hide()
	set_process(false)
	pickup.body_entered.connect(_on_body_entered)


## Configure before entering the tree so pickup starts disabled.
func begin_emergence() -> void:
	_emergence_remaining = EMERGENCE_HEIGHT
	_previous_interpolation_mode = physics_interpolation_mode
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _physics_process(delta: float) -> void:
	if _removing or is_queued_for_deletion():
		return
	if _emergence_remaining > 0.0:
		_emergence_elapsed += delta
		var rise := minf(_emergence_remaining, floorf(_emergence_elapsed / EMERGENCE_STEP_TIME))
		if rise == 0.0:
			return
		_emergence_elapsed -= rise * EMERGENCE_STEP_TIME
		position.y -= rise
		_emergence_remaining -= rise
		_update_emergence_sprite()
		if _emergence_remaining == 0.0:
			physics_interpolation_mode = _previous_interpolation_mode
			reset_physics_interpolation()
			pickup.set_deferred("monitoring", true)
		return
	_advance_available(delta)


func _update_emergence_sprite() -> void:
	# Crop against the block's fixed top edge, even while its sprite bounces.
	sprite.region_enabled = _emergence_remaining > 0.0
	sprite.region_rect = Rect2(
		0, 0, sprite.texture.get_width(), EMERGENCE_HEIGHT - _emergence_remaining
	)
	sprite.offset.y = -_emergence_remaining * 0.5
	sprite.show()


func _advance_available(_delta: float) -> void:
	pass


func remove_offscreen() -> void:
	if _removing or is_shutdown or gameplay_suspended:
		return
	_removing = true
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if (
		_removing or is_queued_for_deletion() or _emergence_remaining > 0.0
		or is_shutdown or gameplay_suspended or activity_suspended
	):
		return
	var player := body.get_parent() as BasePlayer
	if (
		player == null
		or body != player.body
		or player.is_dead
		or player.is_shutdown
		or player.gameplay_suspended
	):
		return
	_removing = true
	report_consumed()
	_grant_reward()
	queue_free()


func _grant_reward() -> void:
	pass

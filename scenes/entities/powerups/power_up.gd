class_name PowerUp
extends SpawnableEntity
## A power-up accepts one valid player contact once it has risen far enough.

const EMERGENCE_HEIGHT := 16.0
const EMERGENCE_STEP_TIME := 4.0 / 60.0
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
const PLAYER_CONTACT := preload("res://scenes/components/interactions/player_contact.gd")

var _removing := false
var _emergence_remaining := 0.0
var _emergence_elapsed := 0.0
var _previous_interpolation_mode: PhysicsInterpolationMode
var _level: BaseLevel

@export var pickup: Area2D
@export_range(0, 16) var minimum_pickup_rise: int = 4


func _ready() -> void:
	_level = BaseLevel.containing(self)
	pickup.monitoring = (
		is_zero_approx(_emergence_remaining) or minimum_pickup_rise < EMERGENCE_HEIGHT
	)
	super()
	DRAW_ORDER.apply(
		sprite, DRAW_ORDER.BEHIND_WORLD if _emergence_remaining > 0.0 else DRAW_ORDER.AVAILABLE_ITEM
	)
	if _emergence_remaining > 0.0:
		sprite.hide()
		SoundHandler.play_reward(&"power_up_reveal")
	set_process(false)


## Configure before entering the tree so pickup follows the emergence threshold.
func begin_emergence() -> void:
	_emergence_remaining = EMERGENCE_HEIGHT
	_previous_interpolation_mode = physics_interpolation_mode
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _physics_process(delta: float) -> void:
	if _removing or is_queued_for_deletion():
		return
	if _emergence_remaining > 0.0:
		_advance_emergence(delta)
		if minimum_pickup_rise < EMERGENCE_HEIGHT and _can_pick_up_at_current_height():
			_check_pickup()
		return
	_advance_available(delta)
	_check_pickup()


func _advance_emergence(delta: float) -> void:
	_emergence_elapsed += delta
	var rise := minf(_emergence_remaining, floorf(_emergence_elapsed / EMERGENCE_STEP_TIME))
	if rise == 0.0:
		return
	_emergence_elapsed -= rise * EMERGENCE_STEP_TIME
	position.y -= rise
	_emergence_remaining -= rise
	_update_emergence_sprite()
	if _emergence_remaining == 0.0:
		var clearance := _emergence_clearance()
		# Keep the settling step in physics and align the artwork to the NES scanline.
		position.y -= clearance
		sprite.offset.y += clearance
		DRAW_ORDER.apply(sprite, DRAW_ORDER.AVAILABLE_ITEM)
		physics_interpolation_mode = _previous_interpolation_mode
		reset_physics_interpolation()
		pickup.set_deferred("monitoring", true)


func _emergence_clearance() -> float:
	return 0.0


func _can_pick_up_at_current_height() -> bool:
	return EMERGENCE_HEIGHT - _emergence_remaining >= minimum_pickup_rise


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


func _check_pickup() -> void:
	if (
		_removing
		or not PLAYER_CONTACT.is_check_tick()
		or not is_instance_valid(_level)
		or is_queued_for_deletion()
		or not _can_pick_up_at_current_height()
		or is_shutdown
		or gameplay_suspended
		or activity_suspended
	):
		return
	var player := _level.player
	if (
		not is_instance_valid(player)
		or player.is_dead
		or player.is_shutdown
		or player.gameplay_suspended
		or not PLAYER_CONTACT.touches(pickup, player.enemy_hurtbox)
	):
		return
	_removing = true
	if not _begin_collection(player):
		_removing = false
		return
	report_consumed()
	_grant_reward(player)
	queue_free()


func _begin_collection(_player: BasePlayer) -> bool:
	return true


## The first draw is 17 pixels above the top of the item frame before artwork offsets.
func reward_popup_position() -> Vector2:
	return sprite.global_position.round() - Vector2(0, 21)


func _grant_reward(_player: BasePlayer) -> void:
	pass

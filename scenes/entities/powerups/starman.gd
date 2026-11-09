class_name Starman
extends PowerUp

const DELAYED_REWARD := preload("res://scenes/components/interactions/delayed_reward.gd")
const RISING_REWARD_POPUP := preload("res://scenes/components/presentation/rising_reward_popup.gd")
const BOUNCE_SPEED := -180.0
const TRAVEL_SPEED := 60.0

var _direction := 1.0
var _probe := PhysicsPointQueryParameters2D.new()

@onready var _motion: MotionValues = $Motion
@onready var _vertical: VerticalMovementComponent = $Motion/VerticalMovement


func _ready() -> void:
	super()
	_probe.collision_mask = _motion.body.collision_mask
	$Presentation/PaletteAnimation.set_enabled(true)


func _advance_available(delta: float) -> void:
	var body := _motion.body
	body.velocity.x = TRAVEL_SPEED * _direction
	var next_speed := _vertical.prepare_step(_motion, delta)
	body.global_position += body.velocity * delta
	_vertical.finish_step(_motion, next_speed)
	# The reference compares the low byte of speed plus two before checking support.
	var can_bounce := ((_vertical.integer_speed + 2) & 0xff) >= 3
	if can_bounce and _solid_at(body.global_position + Vector2(0, 8)):
		# Land at the same tile-relative height as the jumping-enemy routine.
		body.global_position.y = floorf(body.global_position.y / 16.0) * 16.0 + 8.0
		body.velocity.y = BOUNCE_SPEED
	if _solid_at(body.global_position + Vector2(8 * _direction, 4)):
		_direction = -_direction
		body.velocity.x = TRAVEL_SPEED * _direction


func _solid_at(point: Vector2) -> bool:
	_probe.position = point + Vector2(0.01, 0.01)
	var space := get_world_2d().direct_space_state
	_probe.canvas_instance_id = 0
	if not space.intersect_point(_probe, 1).is_empty():
		return true
	var canvas := get_canvas_layer_node()
	if canvas == null:
		return false
	_probe.canvas_instance_id = canvas.get_instance_id()
	return not space.intersect_point(_probe, 1).is_empty()


func _grant_reward(player: BasePlayer) -> void:
	var mario := player as Mario
	if mario != null:
		mario.starman.begin()
	RISING_REWARD_POPUP.show_score(get_parent(), 1000, reward_popup_position())
	DELAYED_REWARD.schedule(self, GameHandler.add_score.bind(1000), 5)
	SoundHandler.play_reward(&"power_up_grab")

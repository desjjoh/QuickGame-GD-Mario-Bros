class_name MovingLift
extends SpawnableEntity
## Moves after the player. Contact uses the old lift position and carry uses the new one.

enum Direction { UP = -1, DOWN = 1 }
enum Motion { REPEATING, HORIZONTAL, VERTICAL }

const SIZE := Vector2(48, 13)
const FRACTION_UNITS := 16
const SPEED_UNITS := 15
const HORIZONTAL_OSCILLATION = preload("res://scenes/components/motion/horizontal_oscillation.gd")
const VERTICAL_OSCILLATION = preload("res://scenes/components/motion/vertical_oscillation.gd")
const PLAYER_CONTACT := preload("res://scenes/components/interactions/player_contact.gd")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")

@export var direction: Direction = Direction.UP

var fraction := 0
var outgoing_y := INF
var motion := Motion.REPEATING
var _horizontal_motion: HORIZONTAL_OSCILLATION
var _vertical_motion: VERTICAL_OSCILLATION
var _top_y := 0
var _center_y := 0
var _level: BaseLevel


func _ready() -> void:
	super()
	_level = BaseLevel.containing(self)
	DRAW_ORDER.apply($Presentation, DRAW_ORDER.ENEMY)


func _physics_process(delta: float) -> void:
	super(delta)
	var player := _level.player as Mario if is_instance_valid(_level) else null
	if is_instance_valid(player) and player.form_presentation.blocks_actor_motion():
		return
	var rider := is_instance_valid(player) and player.can_contact_lift() and _check_contact(player)
	var step := _motion_step(GameHandler.animation_clock.tick_count)
	position += step
	if rider and not reached_outgoing_edge():
		player.land_on_lift(self, step.x)
	elif is_instance_valid(player):
		player.release_lift_support(self)


func configure_oscillation(horizontal: bool, area_y: int) -> void:
	if horizontal:
		motion = Motion.HORIZONTAL
		_horizontal_motion = HORIZONTAL_OSCILLATION.new(14)
	else:
		motion = Motion.VERTICAL
		_vertical_motion = VERTICAL_OSCILLATION.new(5, 10, 3)
		# Platform motion is local to its spawner. The NES sets its references
		# from the starting Y byte, even when the area is translated in Godot.
		var start_y := posmod(area_y, 256)
		if start_y < 128:
			_top_y = 0
			_center_y = 64
		else:
			_top_y = 256 - 2 * start_y
			_center_y = -64


func _motion_step(frame: int) -> Vector2:
	match motion:
		Motion.HORIZONTAL:
			return Vector2(_horizontal_motion.step(frame), 0)
		Motion.VERTICAL:
			return Vector2(0, _vertical_motion.step(roundi(position.y), _top_y, _center_y, frame))
		_:
			var step := fraction + int(direction) * SPEED_UNITS
			fraction = posmod(step, FRACTION_UNITS)
			return Vector2(0, floori(float(step) / FRACTION_UNITS))


func reached_outgoing_edge() -> bool:
	return is_finite(outgoing_y) and (position.y - outgoing_y) * direction >= 0.0


func supports(player: Mario) -> bool:
	if is_queued_for_deletion() or is_shutdown or gameplay_suspended or activity_suspended:
		return false
	var feet := player.body.global_position
	return (
		is_equal_approx(feet.y, global_position.y)
		and player.body.velocity.y >= 0.0
		and Rect2(global_position, SIZE).intersects(_player_bounds(player), true)
	)


func _check_contact(player: Mario) -> bool:
	var area := _level.active_area
	if area == null or not area.is_ancestor_of(self):
		return false
	var bottom := area.get_activity_region(false).end.y - area.activation_buffer
	if player.body.global_position.y >= bottom:
		return false
	var lift_box := Rect2(global_position.floor(), SIZE)
	var player_box := _player_bounds(player)
	if not lift_box.intersects(player_box, true):
		return false
	var head_overlap := lift_box.end.y - player_box.position.y
	if head_overlap < 4.0 and player.body.velocity.y < 0.0:
		player.body.velocity.y = player.vertical_movement.speed_with_integer(
			player.motion_values, 1
		)
	var foot_overlap := player_box.end.y - lift_box.position.y
	if foot_overlap < 6.0 and player.body.velocity.y >= 0.0:
		return true
	var left_overlap := player_box.end.x - lift_box.position.x
	var right_overlap := lift_box.end.x - player_box.position.x
	if left_overlap < 8.0:
		_impede(player, -1.0)
	elif right_overlap >= 1.0 and right_overlap <= 9.0:
		_impede(player, 1.0)
	return false


func _player_bounds(player: Mario) -> Rect2:
	var shape := player.enemy_hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var bounds := PLAYER_CONTACT.bounds(shape)
	bounds.position = bounds.position.floor()
	return bounds


func _impede(player: Mario, push: float) -> void:
	if player.body.velocity.x * push > 0.0:
		return
	player.body.velocity.x = 0.0
	player.body.global_position.x += push
	player.camera_correction_x += push

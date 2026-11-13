class_name MovingLift
extends SpawnableEntity
## Moves after the player. Contact uses the old lift position and carry uses the new one.

enum Direction { UP = -1, DOWN = 1 }
enum Motion { REPEATING, HORIZONTAL, VERTICAL }
enum Width { SMALL = 2, MEDIUM = 3, LARGE = 4 }

const TILE_WIDTH := 16
const CONTACT_HEIGHT := 13
const FRACTION_UNITS := 16
const SPEED_UNITS := 15
const HORIZONTAL_MAX_SPEED := 14
const VERTICAL_DOWN_FORCE := 5
const VERTICAL_UP_FORCE := 10
const VERTICAL_MAX_SPEED := 3
const HORIZONTAL_OSCILLATION = preload("res://scenes/components/motion/horizontal_oscillation.gd")
const VERTICAL_OSCILLATION = preload("res://scenes/components/motion/vertical_oscillation.gd")
const PLAYER_CONTACT := preload("res://scenes/components/interactions/player_contact.gd")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")

@export var direction: Direction = Direction.UP
@export var platform_width: Width = Width.MEDIUM

var fraction := 0
var outgoing_y := INF
var motion := Motion.REPEATING
var travel_distance := -1
var _horizontal_motion: HORIZONTAL_OSCILLATION
var _vertical_motion: VERTICAL_OSCILLATION
var _top_y := 0
var _center_y := 0
var _travel_progress := 0
var _level: BaseLevel


func _ready() -> void:
	var right := $Presentation/Right as Sprite2D
	if platform_width == Width.SMALL:
		$Presentation/Middle.hide()
		right.position.x = TILE_WIDTH
	elif platform_width == Width.LARGE:
		var extra := right.duplicate() as Sprite2D
		extra.position.x += TILE_WIDTH
		$Presentation.add_child(extra)
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
		_horizontal_motion = HORIZONTAL_OSCILLATION.new(HORIZONTAL_MAX_SPEED)
	else:
		motion = Motion.VERTICAL
		_vertical_motion = VERTICAL_OSCILLATION.new(
			VERTICAL_DOWN_FORCE, VERTICAL_UP_FORCE, VERTICAL_MAX_SPEED
		)
		# Platform motion is local to its spawner. The NES sets its references
		# from the starting Y byte, even when the area is translated in Godot.
		var anchors := vertical_anchors(area_y)
		_top_y = anchors.x
		_center_y = anchors.y


static func vertical_anchors(area_y: int) -> Vector2i:
	var start_y := posmod(area_y, 256)
	return Vector2i(0, 64) if start_y < 128 else Vector2i(256 - 2 * start_y, -64)


func _motion_step(frame: int) -> Vector2:
	if travel_distance >= 0:
		return _bounded_travel_step()
	match motion:
		Motion.HORIZONTAL:
			return Vector2(_horizontal_motion.step(frame), 0)
		Motion.VERTICAL:
			return Vector2(0, _vertical_motion.step(roundi(position.y), _top_y, _center_y, frame))
		_:
			var step := fraction + int(direction) * SPEED_UNITS
			fraction = posmod(step, FRACTION_UNITS)
			return Vector2(0, floori(float(step) / FRACTION_UNITS))


func _bounded_travel_step() -> Vector2:
	if travel_distance == 0:
		return Vector2.ZERO
	var endpoint := travel_distance * FRACTION_UNITS
	_travel_progress = posmod(_travel_progress + SPEED_UNITS, 2 * endpoint)
	var distance := float(mini(_travel_progress, 2 * endpoint - _travel_progress))
	var pixels := roundf(distance / FRACTION_UNITS)
	var target := Vector2(-pixels, 0) if motion == Motion.HORIZONTAL else Vector2(0, pixels)
	return target - position


func reached_outgoing_edge() -> bool:
	return is_finite(outgoing_y) and (position.y - outgoing_y) * direction >= 0.0


func supports(player: Mario) -> bool:
	if is_queued_for_deletion() or is_shutdown or gameplay_suspended or activity_suspended:
		return false
	var feet := player.body.global_position
	return (
		is_equal_approx(feet.y, global_position.y)
		and player.body.velocity.y >= 0.0
		and Rect2(global_position, _contact_size()).intersects(_player_bounds(player), true)
	)


func _check_contact(player: Mario) -> bool:
	var area := _level.active_area
	if area == null or not area.is_ancestor_of(self):
		return false
	var bottom := area.get_activity_region(false).end.y - area.activation_buffer
	if player.body.global_position.y >= bottom:
		return false
	var lift_box := Rect2(global_position.floor(), _contact_size())
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


func _contact_size() -> Vector2:
	return Vector2(platform_width * TILE_WIDTH, CONTACT_HEIGHT)


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

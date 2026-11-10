class_name Mushroom
extends PowerUp
## Walks along terrain, falls off edges, and turns on wall contact.

const BLOCK_LAUNCH_SPEED := -180.0
const TERRAIN_PROBE := preload("res://scenes/components/interactions/terrain_probe.gd")
const TILE_SIZE := 16.0
const FOOT_OFFSET := Vector2(0, 8)
const SIDE_HEIGHT := 4.0

@export var walk_speed := 60.0
# NES downward force $3d in 8-bit fractions, converted at nominal 60 Hz.
@export var gravity := 61.0 / 256.0 * 60.0 * 60.0
# NES maximum integer speed of 3 pixels per tick. The integrator retains the low half fraction.
@export var fall_speed_limit := 180.0

var _direction := 1.0
var _falling := false
var _area: BaseLevelArea
var _probe := PhysicsPointQueryParameters2D.new()
var _launch_presentation := (
	preload("res://scenes/components/presentation/block_launch_presentation.gd").new()
)

@onready var body: CharacterBody2D = $Body
@onready var _motion: MotionValues = $Motion
@onready var _vertical: VerticalMovementComponent = $Motion/VerticalMovement


func _ready() -> void:
	super()
	$Body/BlockHitReceiver.hit_handler = _on_block_hit
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevelArea:
		ancestor = ancestor.get_parent()
	_area = ancestor as BaseLevelArea
	if is_instance_valid(_level):
		_level.ignore_player_body(body)


func _emergence_clearance() -> float:
	# Walk from one pixel above the block so the settling fall builds its fraction.
	return 1.0


func _advance_available(delta: float) -> void:
	var holding := _launch_presentation.is_holding()
	if holding and _launch_presentation.is_hit_tick():
		return

	# Point queries do not inherit the terrain body's player collision exception.
	var excluded_bodies: Array[RID] = [body.get_rid()]
	if is_instance_valid(_level) and is_instance_valid(_level.player):
		excluded_bodies.append(_level.player.body.get_rid())
	_probe.exclude = excluded_bodies

	var grid_y := _area.global_position.y if _area != null else 0.0
	body.velocity.x = walk_speed * _direction
	if _falling and not holding:
		_motion.base_gravity = gravity
		_motion.base_max_fall_speed = fall_speed_limit
		var next_speed := _vertical.prepare_step(_motion, delta, grid_y)
		body.global_position += body.velocity * delta
		_vertical.finish_step(_motion, next_speed)
	else:
		body.global_position.x += body.velocity.x * delta
	if holding:
		# The first update after the hit moves horizontally at the lifted height.
		_launch_presentation.reveal(sprite, _launch_presentation.original_position)

	var feet := body.global_position + FOOT_OFFSET
	var depth := fposmod(feet.y - grid_y, TILE_SIZE)
	# The NES accepts floor contact in the first five pixels of the tile.
	if depth < 5.0 and _solid_at(feet):
		if _falling:
			body.global_position.y -= depth
			body.velocity.y = 0.0
			_falling = false
			return
	else:
		_falling = true

	if _solid_at(body.global_position + Vector2(8.0 * _direction, SIDE_HEIGHT)):
		_direction = -_direction
		body.velocity.x = walk_speed * _direction


func _solid_at(point: Vector2) -> bool:
	_probe.position = point + Vector2(0.001, 0.001)
	_probe.collision_mask = body.collision_mask
	return TERRAIN_PROBE.hits_terrain(self, _probe)


func _on_block_hit(hit: EntityHit) -> bool:
	if _removing or is_queued_for_deletion() or _emergence_remaining > 0.0:
		return false
	if is_shutdown or gameplay_suspended or activity_suspended:
		return false
	body.position.y -= 2.0
	_launch_presentation.capture(sprite)
	body.reset_physics_interpolation()
	_falling = true
	body.velocity.y = BLOCK_LAUNCH_SPEED
	var player := hit.attacker as BasePlayer
	if is_instance_valid(player):
		_direction = -1.0 if body.global_position.x < player.body.global_position.x else 1.0
	else:
		_direction = -_direction
	body.velocity.x = walk_speed * _direction
	return true

extends EntityState
## Shared patrol movement for enemies with a BaseEnemy terrain body.

const TERRAIN_WALK := preload("res://scenes/components/motion/terrain_walk.gd")
const TERRAIN_PROBE := preload("res://scenes/components/interactions/terrain_probe.gd")
const FOOT_OFFSET := Vector2(0.001, 8.0)
const FLOOR_DEPTH := 5.0
const TILE_SIZE := 16.0

@export var walk_speed := 30.0
@export var gravity := 61.0 / 256.0 * 60.0 * 60.0
@export var fall_speed_limit := 180.0
@export_enum("Left:-1", "Right:1") var initial_direction: int = -1
## Artwork faces left by default; symmetric enemies can leave this disabled.
@export var face_movement: bool = false
@export var use_center_foot_support := false
@export var use_leading_side_probe := false
@export var turn_toward_player_on_landing := false
@export var turn_at_ledges := false

var has_center_support := false
var _direction: int
var _falling := false
var _terrain_probe: PhysicsPointQueryParameters2D
var _motion: MotionValues
var _vertical: VerticalMovementComponent


func enter() -> void:
	_direction = initial_direction
	_update_facing()
	var enemy := entity as BaseEnemy
	enemy.enemy_contact.connect(_on_enemy_contact)
	if use_center_foot_support:
		if _motion == null:
			_terrain_probe = PhysicsPointQueryParameters2D.new()
			_motion = MotionValues.new()
			_motion.body = enemy.body
			_motion.base_gravity = gravity
			_motion.base_max_fall_speed = fall_speed_limit
			add_child(_motion)
			_vertical = VerticalMovementComponent.new()
			add_child(_vertical)
		has_center_support = false
		_falling = false
		_vertical.reset_fraction()


func exit() -> void:
	(entity as BaseEnemy).enemy_contact.disconnect(_on_enemy_contact)


func process_physics(delta: float) -> BaseState:
	if use_center_foot_support:
		_advance_center_foot_walk(delta)
	else:
		_move_with_horizontal_speed(delta, walk_speed * _direction)
	return null


func _advance_center_foot_walk(delta: float) -> void:
	var enemy := entity as BaseEnemy
	var body := enemy.body
	var level := enemy._level
	var area := level.active_area if is_instance_valid(level) else null
	var grid_origin := area.global_position if is_instance_valid(area) else Vector2.ZERO
	var feet := body.global_position + FOOT_OFFSET
	var tolerance := body.safe_margin + 0.001
	_terrain_probe.position = feet + Vector2(0.0, tolerance)
	_terrain_probe.collision_mask = body.collision_mask
	var player := level.player if is_instance_valid(level) else null
	_terrain_probe.exclude = [player.body.get_rid()] if is_instance_valid(player) else []
	var depth := fposmod(_terrain_probe.position.y - grid_origin.y, TILE_SIZE)
	var was_supported := has_center_support
	has_center_support = (
		body.velocity.y >= 0.0
		and depth < FLOOR_DEPTH
		and TERRAIN_PROBE.hits_terrain(enemy, _terrain_probe)
	)
	if turn_at_ledges and was_supported and not has_center_support:
		_turn_around()
		_move_center_foot_horizontal(body, delta, false, grid_origin)
		return
	var landed := _falling and has_center_support
	if has_center_support:
		if landed and turn_toward_player_on_landing and is_instance_valid(player):
			# The NES compares whole-pixel X and chooses left when both are equal.
			_direction = (
				1 if floorf(player.body.global_position.x) > floorf(body.global_position.x) else -1
			)
			_update_facing()
		body.global_position.y += tolerance - depth
		body.velocity.y = 0.0
	_falling = not has_center_support

	_move_center_foot_horizontal(body, delta, landed, grid_origin)
	if not has_center_support:
		var next_speed := _vertical.prepare_step(_motion, delta, grid_origin.y)
		body.global_position.y += body.velocity.y * delta
		body.velocity.y = next_speed


func _move_center_foot_horizontal(
	body: CharacterBody2D, delta: float, landed: bool, grid_origin: Vector2
) -> void:
	if use_leading_side_probe:
		if has_center_support and not landed and _has_leading_side_terrain(body, grid_origin):
			_turn_around()
		body.velocity.x = walk_speed * _direction
		body.global_position.x += body.velocity.x * delta
		return

	body.velocity.x = walk_speed * _direction
	var horizontal_step := Vector2(body.velocity.x * delta, 0.0)
	var travel_direction := signf(horizontal_step.x)
	var wall := KinematicCollision2D.new()
	if (
		body.test_move(body.global_transform, horizontal_step, wall)
		and wall.get_normal().x * travel_direction < -0.5
		and (wall.get_position().x - body.global_position.x) * travel_direction > 0.0
	):
		body.global_position.x += clampf(
			wall.get_travel().x, minf(horizontal_step.x, 0.0), maxf(horizontal_step.x, 0.0)
		)
		body.velocity.x = 0.0
		_turn_around()
	else:
		body.global_position.x += horizontal_step.x


func _has_leading_side_terrain(body: CharacterBody2D, grid_origin: Vector2) -> bool:
	var epsilon := Vector2(0.001, 0.001)
	var pixel := (body.global_position - grid_origin + epsilon).floor() + grid_origin
	# The reference samples the leading side four pixels above the feet.
	_terrain_probe.position = pixel + Vector2(8.0 * _direction, 4.0) + epsilon
	return TERRAIN_PROBE.hits_terrain(body, _terrain_probe)


func _move_with_horizontal_speed(delta: float, horizontal_speed: float) -> void:
	var enemy := entity as BaseEnemy
	var body := enemy.body
	var hit_wall := TERRAIN_WALK.step(body, horizontal_speed)
	body.velocity.y = minf(body.velocity.y + gravity * delta, fall_speed_limit)
	if hit_wall:
		_turn_around()


func _turn_around() -> void:
	_direction = -_direction
	_update_facing()


func _update_facing() -> void:
	if face_movement:
		entity.sprite.flip_h = _direction > 0


func _on_enemy_contact(_other: BaseEnemy) -> void:
	_turn_around()

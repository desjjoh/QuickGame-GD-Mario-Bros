extends "res://scripts/states/enemies/koopa_shell_idle_state.gd"

const CHAIN_POINTS := [500, 800, 1000, 2000, 4000, 5000, 8000]
const BLOCK_ROLL_SPEED := 60.0
const AIRBORNE_SPEED_ADJUSTMENT := 90.0
enum BlockLaunch { NONE, HIT_FRAME, AIRBORNE, FLOOR_CONTACT }

var _touching: Dictionary[int, bool] = {}
var _block_launch := BlockLaunch.NONE
var _last_movement_tick := -1
var _struck_block: BaseBlock
var _ignores_struck_block := false
var _launch_motion: MotionValues
var _launch_vertical: VerticalMovementComponent
var _launch_y_origin := 0.0


func enter() -> void:
	walk_speed = 180.0
	_block_launch = BlockLaunch.NONE
	_last_movement_tick = -1
	super.enter()
	_touching.clear()
	(entity as BaseEnemy).body.velocity.x = walk_speed * _direction


func process_physics(delta: float) -> BaseState:
	var enemy := entity as BaseEnemy
	_last_movement_tick = Engine.get_physics_frames()
	_advance_shell(enemy.body, delta)
	var present: Dictionary[int, bool] = {}
	for area: Area2D in enemy._enemy_contact_area.get_overlapping_areas():
		var other := area.get_parent().get_parent() as BaseEnemy
		if other == null or other == enemy:
			continue
		present[other.get_instance_id()] = true
		enemy._on_enemy_contact(area)
		if enemy._defeated or enemy.is_shutdown:
			return null
	for id: int in _touching.keys():
		if not present.has(id):
			_touching.erase(id)
	return null


func exit() -> void:
	_restore_struck_block_collision()
	_struck_block = null
	super.exit()


func begin_block_launch(direction: int, struck_block: BaseBlock) -> void:
	_restore_struck_block_collision()
	_struck_block = struck_block
	if _launch_motion == null:
		_launch_motion = MotionValues.new()
		_launch_motion.name = "LaunchMotion"
		_launch_motion.body = (entity as BaseEnemy).body
		add_child(_launch_motion)
		_launch_vertical = VerticalMovementComponent.new()
		_launch_vertical.name = "LaunchVertical"
		add_child(_launch_vertical)
	_launch_motion.base_gravity = gravity
	_launch_motion.base_max_fall_speed = fall_speed_limit
	_launch_vertical.reset_fraction()
	_launch_y_origin = _launch_motion.body.global_position.y
	walk_speed = BLOCK_ROLL_SPEED
	_direction = direction
	# A late bonk already follows this tick's ordinary shell movement.
	_block_launch = BlockLaunch.HIT_FRAME
	if _last_movement_tick == Engine.get_physics_frames():
		_block_launch = BlockLaunch.AIRBORNE


func _advance_shell(body: CharacterBody2D, delta: float) -> void:
	if _block_launch == BlockLaunch.HIT_FRAME:
		# The hit applies the lift. The moving shell only advances horizontally this update.
		var collision := body.move_and_collide(Vector2(walk_speed * _direction * delta, 0.0))
		if collision != null and absf(collision.get_normal().x) > 0.5:
			_turn_around()
		_block_launch = BlockLaunch.AIRBORNE
		return
	if _block_launch == BlockLaunch.NONE:
		super.process_physics(delta)
		_release_cleared_brick(body)
		return
	if _block_launch == BlockLaunch.FLOOR_CONTACT:
		# The NES accepts support before movement, on the tick after reaching it.
		_ignore_unsupported_block_edge(body, delta)
		var support := KinematicCollision2D.new()
		var probe := Vector2(0.0, body.safe_margin * 2.0 + 0.001)
		if (
			body.test_move(body.global_transform, probe, support)
			and support.get_normal().dot(body.up_direction) >= cos(body.floor_max_angle)
		):
			_block_launch = BlockLaunch.NONE
			_move_with_horizontal_speed(delta, walk_speed * _direction)
			body.velocity = Vector2(walk_speed * _direction, 0.0)
			_release_cleared_brick(body)
			if not _ignores_struck_block:
				_struck_block = null
			return
		_block_launch = BlockLaunch.AIRBORNE

	var next_vertical_speed := _launch_vertical.prepare_step(
		_launch_motion, delta, _launch_y_origin
	)
	_ignore_unsupported_block_edge(body, delta)
	if (
		_ignores_struck_block
		and is_instance_valid(_struck_block)
		and body.collision_mask & _struck_block.body.collision_layer
	):
		var side_probe := body.global_position + Vector2(8.0 * _direction, 4.0)
		if _body_bounds(_struck_block.body).has_point(side_probe):
			_turn_around()
	body.velocity.x = (walk_speed - AIRBORNE_SPEED_ADJUSTMENT) * _direction
	body.move_and_slide()
	if body.is_on_wall():
		_turn_around()
	_release_cleared_brick(body)
	if body.is_on_floor():
		_block_launch = BlockLaunch.FLOOR_CONTACT
		# Keep a downward sweep available for the next tick's grounded movement.
		body.velocity.y = next_vertical_speed
	elif body.is_on_ceiling():
		_launch_vertical.reset_fraction()
		_launch_y_origin = body.global_position.y
		body.velocity.y = _launch_vertical.speed_after_gravity(_launch_motion, delta)
	else:
		_launch_vertical.finish_step(_launch_motion, next_vertical_speed)


func _ignore_unsupported_block_edge(body: CharacterBody2D, delta: float) -> void:
	if _ignores_struck_block or not is_instance_valid(_struck_block) or body.velocity.y <= 0.0:
		return
	var drift_speed := (walk_speed - AIRBORNE_SPEED_ADJUSTMENT) * _direction
	var motion := Vector2(drift_speed, body.velocity.y) * delta
	var landing := KinematicCollision2D.new()
	if not body.test_move(body.global_transform, motion, landing):
		return
	var floor_normal := cos(body.floor_max_angle)
	if landing.get_normal().dot(body.up_direction) < floor_normal:
		return
	if landing.get_collider() == _struck_block.body:
		var bounds := _body_bounds(_struck_block.body)
		# The sweep finds the top. Only a bottom-center probe over the tile can land on it.
		if not bounds.has_point(Vector2(body.global_position.x, bounds.position.y)):
			body.add_collision_exception_with(_struck_block.body)
			_ignores_struck_block = true


func _release_cleared_brick(body: CharacterBody2D) -> void:
	if not _ignores_struck_block:
		return
	if not is_instance_valid(_struck_block):
		_ignores_struck_block = false
		_struck_block = null
		return
	var brick_bounds := _body_bounds(_struck_block.body).grow(body.safe_margin)
	if not _body_bounds(body).intersects(brick_bounds):
		_restore_struck_block_collision()
		if _block_launch == BlockLaunch.NONE:
			_struck_block = null


func _restore_struck_block_collision() -> void:
	if _ignores_struck_block and is_instance_valid(_struck_block):
		(entity as BaseEnemy).body.remove_collision_exception_with(_struck_block.body)
	_ignores_struck_block = false


func _body_bounds(body: PhysicsBody2D) -> Rect2:
	var shape := body.get_node("CollisionShape2D") as CollisionShape2D
	return shape.global_transform * shape.shape.get_rect()


func _turn_around() -> void:
	super._turn_around()
	entity.play_sound_effect(SoundHandler.get_sound(&"bump"))


func _on_enemy_contact(other: BaseEnemy) -> void:
	var enemy := entity as BaseEnemy
	if enemy._defeated or enemy.state_machine.current_state != self:
		return
	if _touching.has(other.get_instance_id()) or not other._blocks_enemy_contact():
		return
	var position := (
		other.sprite.global_position if other.sprite != null else other.body.global_position
	)
	var mutual := other.is_moving_shell()
	if not other.receive_hit(EntityHit.new(enemy, &"shell", Vector2(_direction, 0))):
		return
	# Only accepted reactions consume the overlap. A temporarily unavailable
	# target must remain eligible when the next physics poll sees it again.
	_touching[other.get_instance_id()] = true
	if not other._defeated:
		return  # A surviving reaction is not a chain defeat.
	if mutual:
		var own_position := enemy.sprite.global_position
		if enemy.receive_hit(EntityHit.new(other, &"shell", Vector2(-_direction, 0))):
			enemy.award_score(1000, own_position)
	enemy.play_sound_effect(SoundHandler.get_sound(&"enemy_smack"))
	if enemy.shell_chain < CHAIN_POINTS.size():
		enemy.award_score(CHAIN_POINTS[enemy.shell_chain], position)
	else:
		enemy.award_extra_life(position)
	enemy.shell_chain += 1

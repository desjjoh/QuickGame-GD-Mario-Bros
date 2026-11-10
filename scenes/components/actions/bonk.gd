class_name BonkAction
extends Node
## Resolves regular ceiling contacts and underside crossings on hidden blocks.

const HIDDEN_BLOCK_PROBE_MASK := 1 << 31

var response_velocity_y: float = NAN
var suppress_ceiling_sound := false
var reaction_ticks_remaining := 0
var shattered_ceiling: Node
var _reaction_tick := -1


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() != _reaction_tick:
		reaction_ticks_remaining = maxi(0, reaction_ticks_remaining - 1)
		_reaction_tick = Engine.get_physics_frames()


func reset_reaction_gate() -> void:
	reaction_ticks_remaining = 0
	shattered_ceiling = null


@export var enabled: bool = false
@export var strength: float = 1.0


func deliver_hidden(player: BasePlayer, previous_position: Vector2) -> bool:
	response_velocity_y = NAN
	suppress_ceiling_sound = false
	if not enabled or player.is_shutdown:
		return false
	var shape := player.collision_shape.shape as RectangleShape2D
	if shape == null or player.body.global_position.y >= previous_position.y:
		return false
	var head := player.get_head_position() + Vector2(0.0001, 0)
	var previous_head := head + previous_position - player.body.global_position
	var query := PhysicsRayQueryParameters2D.create(
		previous_head + Vector2(0, 0.001), head, HIDDEN_BLOCK_PROBE_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := player.body.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.5:
		return false
	var block := _find_block(hit.collider as Node) as HiddenQuestionBlock
	if block == null or not _deliver_block(player, block):
		return false
	player.body.global_position.y += hit.position.y - head.y
	return true


## Returns true for a confirmed underside contact, even on an inert ceiling.
func check_ceiling(
	player: BasePlayer, previous_position: Vector2, intended_motion: Vector2
) -> bool:
	response_velocity_y = NAN
	suppress_ceiling_sound = false
	if player.is_shutdown or not player.body.is_on_ceiling():
		return false
	var head := player.get_head_position() + Vector2(0.001, 0)
	var shape := player.collision_shape.shape as RectangleShape2D
	if shape == null or head.y < player.collision_shape.global_position.y - shape.size.y / 2.0 - 0.001:
		return false  # MarioTerrain owns ceilings above the short collision body.
	var previous_head := head + previous_position - player.body.global_position
	var query := PhysicsRayQueryParameters2D.create(
		head + Vector2(0, 0.5),
		head - Vector2(0, 0.5),
		player.body.collision_mask,
		[player.body.get_rid()]
	)
	var space := player.body.get_world_2d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.5 or previous_head.y + 0.001 < hit.position.y:
		return false
	if not is_zero_approx(intended_motion.x):
		# The rectangle can catch first and then slide under the brick in X.
		# The center must have reached the same underside on its approach.
		var margin := intended_motion.normalized() * 0.001
		query.from = previous_head - margin
		query.to = previous_head + intended_motion + margin
		var approach := space.intersect_ray(query)
		if approach.is_empty() or approach.normal.y < 0.5 or approach.collider != hit.collider:
			return false
	deliver_at(player, hit.collider)
	return true


## Reference head-probe contacts can occur above the short floor-support body.
func deliver_at(player: BasePlayer, collider: Node) -> bool:
	response_velocity_y = NAN
	suppress_ceiling_sound = false
	if not enabled or player.is_shutdown or collider == null:
		return false
	var target := _find_block(collider)
	if target == null or not _deliver_block(player, target):
		return false
	if suppress_ceiling_sound:
		shattered_ceiling = collider
	return true


func _find_block(collider: Node) -> BaseBlock:
	var ancestor := collider
	while ancestor != null and not ancestor is BaseBlock:
		ancestor = ancestor.get_parent()
	return ancestor as BaseBlock


func _deliver_block(player: BasePlayer, target: BaseBlock) -> bool:
	if (
		reaction_ticks_remaining > 0
		or not target.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP, strength))
	):
		return false
	response_velocity_y = target.bonk_velocity_y
	suppress_ceiling_sound = not is_nan(response_velocity_y) and response_velocity_y < 0.0
	if not is_nan(response_velocity_y):
		response_velocity_y = player.vertical_movement.speed_with_integer(
			player.motion_values, int(response_velocity_y / 60.0)
		)
	reaction_ticks_remaining = 16
	_reaction_tick = Engine.get_physics_frames()
	return true

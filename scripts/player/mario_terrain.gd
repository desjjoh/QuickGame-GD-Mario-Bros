class_name MarioTerrain
extends Node
## Mario's terrain probes share the short body with standing head and side checks.
enum FloorStep { SWEEP, LAND, CLEAR_CORNER }

const FLOOR_DEPTH := 4.0
const FLOOR_CLEARANCE := 0.125
const PROBE_EPSILON := 0.001
const STANDING_HEAD := Vector2(0, -28)
const SHORT_HEAD := Vector2(0, -14)
const FEET := [Vector2(-5, 0), Vector2(4, 0)]
const STANDING_SIDES := [Vector2(-6, -24), Vector2(-6, -8), Vector2(5, -24), Vector2(5, -8)]
const SHORT_SIDES := [Vector2(-6, -8), Vector2(-6, -8), Vector2(5, -8), Vector2(5, -8)]
var _last_coin_tick := -1


func step_floor(player: BasePlayer, delta: float) -> FloorStep:
	var body := player.body
	var start := body.global_position
	var motion := body.velocity * delta
	var target := start + motion
	# Ground support lives on the pixel grid even when Godot leaves a safe margin.
	var feet := _foot_origin(target)
	for offset: Vector2 in FEET:
		var top := _surface_at(body, feet + offset)
		if not top.is_empty() and _can_cross_at_top(body, motion.x, top.position.y):
			_settle_on_surface(body, target.x, top.position.y, delta)
			return FloorStep.LAND

	if is_zero_approx(motion.x):
		return FloorStep.SWEEP
	# The rectangle can hit a corner its inset foot has yet to reach.
	var side := signf(motion.x)
	var shape := player.collision_shape
	var half_width := (shape.shape as RectangleShape2D).size.x / 2.0
	var outer_x := shape.global_position.x + motion.x + side * (half_width + PROBE_EPSILON)
	var corner := _surface_at(body, Vector2(outer_x, feet.y))
	if corner.is_empty():
		return FloorStep.SWEEP
	var leading_foot := feet + (FEET[1] if side > 0.0 else FEET[0])
	var point := PhysicsPointQueryParameters2D.new()
	point.position = leading_foot + Vector2.ONE * PROBE_EPSILON
	point.collision_mask = body.collision_mask
	point.exclude = [body.get_rid()]
	if not _terrain_at(player, point).is_empty():
		# A deep foot contact belongs to the solid side.
		return FloorStep.SWEEP
	if not _can_cross_at_top(body, motion.x, corner.position.y):
		return FloorStep.SWEEP
	# Permit only this shallow outer-edge overlap. The inset feet still decide
	# support, and a subsequent deep foot hit goes through the body sweep.
	body.global_position = Vector2(target.x, feet.y)
	return FloorStep.CLEAR_CORNER


func _surface_at(body: CharacterBody2D, foot: Vector2) -> Dictionary:
	var x := foot.x + PROBE_EPSILON
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(x, foot.y - FLOOR_DEPTH - PROBE_EPSILON),
		Vector2(x, foot.y + PROBE_EPSILON),
		body.collision_mask,
		[body.get_rid()]
	)
	var hit := body.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y > -0.7:
		return {}
	return hit


func _can_cross_at_top(body: CharacterBody2D, step_x: float, top: float) -> bool:
	var above := body.global_transform
	above.origin.y = minf(above.origin.y, top - FLOOR_CLEARANCE)
	# Check the horizontal route above this corner so tall and neighboring walls
	# keep their normal collision even when a shallow landing wins.
	return not body.test_move(above, Vector2(step_x, 0), null, body.safe_margin, true)


func _settle_on_surface(body: CharacterBody2D, x: float, top: float, delta: float) -> void:
	var speed_x := body.velocity.x
	body.global_position = Vector2(x, top - FLOOR_CLEARANCE)
	body.velocity = Vector2(0, FLOOR_CLEARANCE / delta)
	body.move_and_slide()
	body.velocity = Vector2(speed_x, 0)


func supports_body(body: CharacterBody2D) -> bool:
	var feet := _foot_origin(body.global_position)
	for offset: Vector2 in FEET:
		var hit := _surface_at(body, feet + offset)
		if not hit.is_empty() and absf(hit.position.y - body.global_position.y) <= FLOOR_CLEARANCE:
			return true
	return false


func _foot_origin(position: Vector2) -> Vector2:
	var level := GameHandler.current_level
	var origin := Vector2.ZERO
	if level != null and level.active_area != null:
		origin = level.active_area.global_position
	var local := position - origin
	return origin + Vector2(floorf(local.x + PROBE_EPSILON), roundf(local.y))


## The NES checks coin metatiles through the same size/posture terrain probes.
func collect_coins(player: BasePlayer, short_profile: bool) -> void:
	if (
		player.is_dead
		or player.is_shutdown
		or player.gameplay_suspended
		or player.activity_suspended
	):
		return
	if player.body.collision_mask == 0:
		return
	var tick := Engine.get_physics_frames()
	if tick == _last_coin_tick:
		return
	_last_coin_tick = tick
	var probes: Array[Vector2] = [SHORT_HEAD if short_profile else STANDING_HEAD]
	probes.append_array(FEET)
	probes.append_array(SHORT_SIDES if short_profile else STANDING_SIDES)
	var query := PhysicsPointQueryParameters2D.new()
	query.collide_with_bodies = false
	query.collide_with_areas = true
	query.collision_mask = 1
	var canvas := player.body.get_canvas_layer_node()
	query.canvas_instance_id = canvas.get_instance_id() if canvas != null else 0
	var space := player.body.get_world_2d().direct_space_state
	for offset: Vector2 in probes:
		# Match block-buffer next-cell ownership on exact tile boundaries.
		query.position = player.body.global_position + offset + Vector2(0.0001, 0.0001)
		for hit: Dictionary in space.intersect_point(query):
			var coin := (hit.collider as Node).get_parent().get_parent() as WorldCoin
			if coin != null and coin.collect(player):
				return  # PlayerBGCollision awards at most one touched coin per update.


func resolve(player: BasePlayer, before: Vector2, was_rising: bool, crouched: bool) -> void:
	if player.body.collision_mask == 0:
		return
	var head := SHORT_HEAD if crouched else STANDING_HEAD
	# The existing short body/bonk path already owns short-posture ceilings.
	# HeadChk uses the NES origin (feet - 32), whose low nibble equals feet mod 16.
	var head_phase := posmod(int(floorf(player.body.global_position.y)), 16)
	if not crouched and was_rising and head_phase >= 4:
		var from := Vector2(player.body.global_position.x, before.y) + head + Vector2(0.0001, 0)
		var to := player.body.global_position + head + Vector2(0.0001, 0.0001)
		if to.y < from.y:
			var query := PhysicsRayQueryParameters2D.create(
				from, to, player.body.collision_mask, [player.body.get_rid()]
			)
			var space := player.body.get_world_2d().direct_space_state
			var hit := space.intersect_ray(query)
			if hit.is_empty() or hit.normal.y <= 0.5:
				# A diagonal step can put the vertical ray's origin inside a tile.
				# Like HeadChk, inspect the current head position as well as entry.
				var point := PhysicsPointQueryParameters2D.new()
				point.position = to
				point.collision_mask = player.body.collision_mask
				point.exclude = [player.body.get_rid()]
				var occupied := _terrain_at(player, point)
				if not occupied.is_empty():
					hit = occupied[0]
					hit["normal"] = Vector2.DOWN
			if not hit.is_empty() and hit.normal.y > 0.5:
				var solid_speed := player.vertical_movement.speed_with_integer(
					player.motion_values, 1
				)
				var bounced := player.bonk_action.deliver_at(player, hit.collider)
				player.respond_to_ceiling()
				# BumpBlock stops upward motion; NYSpd reverses solid contact.
				# Keep the accepted block reaction distinct from rejected/used solids.
				if bounced:
					player.body.velocity.y = (
						0.0
						if is_nan(player.bonk_action.response_velocity_y)
						else player.bonk_action.response_velocity_y
					)
				else:
					player.body.velocity.y = solid_speed

	if crouched:
		return
	# Fixed left-first order, one encountered obstruction per update, as in SideCheckLoop.
	for index in range(STANDING_SIDES.size()):
		var offset: Vector2 = STANDING_SIDES[index]
		var query := PhysicsPointQueryParameters2D.new()
		query.position = player.body.global_position + offset + Vector2(0.0001, 0.0001)
		query.collision_mask = player.body.collision_mask
		query.exclude = [player.body.get_rid()]
		var blocked := false
		for hit: Dictionary in _terrain_at(player, query):
			var pipe := (hit.collider as Node).get_parent() as PipeEntrance
			if pipe != null and pipe.sideways and index % 2 == 0:
				continue
			blocked = true
			break
		if not blocked:
			continue
		var push := 1.0 if index < 2 else -1.0
		if player.body.velocity.x * push <= 0.0:
			player.body.velocity.x = 0.0
			player.body.global_position.x += push
		return


## TileMap bodies use the default canvas; entity bodies inherit Game's CanvasLayer.
func _terrain_at(player: BasePlayer, query: PhysicsPointQueryParameters2D) -> Array[Dictionary]:
	var space := player.body.get_world_2d().direct_space_state
	query.canvas_instance_id = 0
	var hits := space.intersect_point(query)
	var canvas := player.body.get_canvas_layer_node()
	if canvas != null:
		query.canvas_instance_id = canvas.get_instance_id()
		hits.append_array(space.intersect_point(query))
	return hits

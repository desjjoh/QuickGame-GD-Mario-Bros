class_name CornerCorrectionComponent
extends Node
## Bounded approximation of SMB's separate head/foot terrain probes.

@export var landing_tolerance: float = 4.0
const HEAD_ESCAPE_STEP := 0.25


func _ray(body: CharacterBody2D, from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, body.collision_mask, [body.get_rid()])
	return body.get_world_2d().direct_space_state.intersect_ray(query)


func _clear(body: CharacterBody2D, at: Vector2) -> bool:
	var transform := body.global_transform
	transform.origin = at
	return not body.test_move(transform, Vector2.ZERO, null, 0.01, true)


func prepare(body: CharacterBody2D, shape: CollisionShape2D, delta: float) -> bool:
	if not shape.shape is RectangleShape2D:
		return false
	var half := (shape.shape as RectangleShape2D).size / 2.0
	var motion := body.velocity * delta
	if motion.y < 0.0:
		_correct_head(body, shape, half, motion)
	elif motion.y > 0.0 and not body.is_on_floor():
		return _correct_landing(body, shape, half, motion)
	return false


func _correct_head(
	body: CharacterBody2D, shape: CollisionShape2D, half: Vector2, motion: Vector2
) -> void:
	var collision := KinematicCollision2D.new()
	if (
		not body.test_move(body.global_transform, motion, collision)
		or collision.get_normal().y < 0.7
	):
		return
	var head := Vector2(body.global_position.x, shape.global_position.y - half.y)
	var projected_head := head + Vector2(collision.get_travel().x, 0)
	if not _ray(body, projected_head, projected_head + Vector2(0, motion.y - 0.1)).is_empty():
		return
	var preferred := 1.0 if body.velocity.x >= 0.0 else -1.0
	var shape_offset := absf(shape.global_position.x - head.x)
	var escape_limit := half.x + shape_offset + body.safe_margin
	for step in range(1, ceili(escape_limit / HEAD_ESCAPE_STEP) + 1):
		var distance := minf(step * HEAD_ESCAPE_STEP, escape_limit)
		for direction in [preferred, -preferred]:
			var offset := Vector2(distance * direction, 0)
			var candidate := body.global_position + offset
			if not _clear(body, candidate) or body.test_move(body.global_transform, offset):
				continue
			var transform := body.global_transform
			transform.origin = candidate
			if not body.test_move(transform, motion):
				body.global_position = candidate
				return


func _correct_landing(
	body: CharacterBody2D, shape: CollisionShape2D, half: Vector2, motion: Vector2
) -> bool:
	var feet_y := shape.global_position.y + half.y
	# Check inset feet first. Physical-edge fallbacks prevent Godot side sweeps
	# from snagging shallow gap crossings before an inset probe reaches terrain.
	for foot_x in [
		shape.global_position.x - half.x + 1.0,
		shape.global_position.x + half.x - 1.0,
		shape.global_position.x - half.x + 0.01,
		shape.global_position.x + half.x - 0.01
	]:
		var x: float = foot_x + motion.x
		var hit := _ray(
			body, Vector2(x, feet_y - landing_tolerance - 0.1), Vector2(x, feet_y + motion.y + 0.1)
		)
		if hit.is_empty() or (hit.normal as Vector2).y > -0.7:
			continue
		var penetration: float = feet_y - (hit.position as Vector2).y
		# Mixing old Y with projected X can rescue a landing already too deep.
		var projected_penetration := penetration + motion.y
		if projected_penetration > landing_tolerance + 0.0001 or projected_penetration <= 0.0:
			continue
		var lift := maxf(penetration + 0.1, 0.0)
		var raised := body.global_position - Vector2(0, lift)
		if not _clear(body, raised) or not _clear(body, raised + Vector2(motion.x, 0)):
			continue
		if body.test_move(body.global_transform, Vector2(0, -lift)):
			continue
		var raised_transform := body.global_transform
		raised_transform.origin = raised
		if body.test_move(raised_transform, Vector2(motion.x, 0)):
			continue
		# Complete the checked horizontal step above the corner before falling
		# onto it. A diagonal sweep can otherwise strike the side again.
		body.global_position = raised + Vector2(motion.x, 0)
		return true
	return false

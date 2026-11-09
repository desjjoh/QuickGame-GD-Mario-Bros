extends RefCounted
## Holds a sprite at its pre-launch position until the next physics update.

var original_position := Vector2.ZERO
var _held_world_position := Vector2.ZERO
var _hit_tick := -1


func is_holding() -> bool:
	return _hit_tick >= 0


func is_hit_tick() -> bool:
	return Engine.get_physics_frames() == _hit_tick


func capture(sprite: Sprite2D) -> void:
	if not is_holding():
		original_position = sprite.position
	_held_world_position = sprite.global_position
	_hit_tick = Engine.get_physics_frames()


func hold_after_motion(sprite: Sprite2D, body: Node2D) -> void:
	sprite.global_position = _held_world_position
	body.reset_physics_interpolation()


func reveal(sprite: Sprite2D, position: Vector2) -> void:
	sprite.position = position
	sprite.reset_physics_interpolation()
	_hit_tick = -1


func cancel(sprite: Sprite2D) -> void:
	if is_holding():
		reveal(sprite, original_position)

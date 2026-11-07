class_name EnemyDefeatedState
extends EntityState

@export var duration := 0.5
@export var launch_speed := 0.0
@export var horizontal_speed := 0.0

var launch_direction := 1.0

var _elapsed := 0.0
var _velocity := Vector2.ZERO


func enter() -> void:
	_elapsed = 0.0
	_velocity = Vector2(horizontal_speed * launch_direction, launch_speed)
	(entity as BaseEnemy).body.velocity = Vector2.ZERO
	entity.sprite.flip_v = launch_speed != 0.0


func process_physics(delta: float) -> BaseState:
	_elapsed += delta
	if launch_speed != 0.0:
		var body := (entity as BaseEnemy).body
		body.position += _velocity * delta
		_velocity.y = minf(_velocity.y + 61.0 / 256.0 * 60.0 * 60.0 * delta, 180.0)
		return null
	if _elapsed >= duration:
		entity.queue_free()
	return null

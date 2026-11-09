extends "res://scripts/states/enemies/walking_enemy_state.gd"
## Recoverable block launch; contact can kick it before it lands.

var _launch_presentation := (
	preload("res://scenes/components/presentation/block_launch_presentation.gd").new()
)


func begin_block_launch(direction: int) -> void:
	_launch_presentation.capture(entity.sprite)
	_direction = direction
	var body := (entity as BaseEnemy).body
	body.position.y -= 2.0
	body.velocity = Vector2(walk_speed * _direction, -180.0)
	# Take the first launch step here so early and late hits consume it equally.
	var collision := body.move_and_collide(body.velocity / 60.0)
	if collision != null:
		var normal := collision.get_normal()
		body.move_and_collide(collision.get_remainder().slide(normal))
		body.velocity = body.velocity.slide(normal)
		if absf(normal.x) > 0.5:
			_turn_around()
	body.velocity.y = minf(body.velocity.y + gravity / 60.0, fall_speed_limit)
	_launch_presentation.hold_after_motion(entity.sprite, body)


func exit() -> void:
	_launch_presentation.cancel(entity.sprite)
	super.exit()


func process_physics(delta: float) -> BaseState:
	if _launch_presentation.is_holding():
		if _launch_presentation.is_hit_tick():
			return null
		entity.sprite.vframes = 2
		entity.sprite.frame = 4
		# Align the inverted launch artwork to the terrain body's feet.
		entity.sprite.flip_v = true
		_launch_presentation.reveal(entity.sprite, Vector2.ZERO)
	super.process_physics(delta)
	var enemy := entity as BaseEnemy
	var idle = enemy.get_node("StateMachine/ShellIdle")
	idle.wake_ticks_remaining = maxi(0, idle.wake_ticks_remaining - 1)
	if enemy.body.is_on_floor() and enemy.body.velocity.y >= 0.0:
		return idle
	return null

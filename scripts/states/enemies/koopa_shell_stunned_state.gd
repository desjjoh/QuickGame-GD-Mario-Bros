extends "res://scripts/states/enemies/walking_enemy_state.gd"
## Recoverable block launch; contact can kick it before it lands.


func enter() -> void:
	super.enter()
	entity.sprite.vframes = 2
	entity.sprite.frame = 4
	entity.sprite.position = Vector2(0, 2)
	entity.sprite.flip_v = true


func process_physics(delta: float) -> BaseState:
	super.process_physics(delta)
	var enemy := entity as BaseEnemy
	var idle = enemy.get_node("StateMachine/ShellIdle")
	idle.wake_ticks_remaining = maxi(0, idle.wake_ticks_remaining - 1)
	if enemy.body.is_on_floor() and enemy.body.velocity.y >= 0.0:
		return idle
	return null

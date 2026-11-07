extends "res://scripts/states/enemies/walking_enemy_state.gd"
## Zero-speed Walking retains shared falling/terrain behavior for the shell.

const WAKE_TICKS := 336
const WARNING_TICKS := 84
var wake_ticks_remaining := WAKE_TICKS


func enter() -> void:
	super.enter()
	wake_ticks_remaining = WAKE_TICKS
	var enemy := entity as BaseEnemy
	enemy.body.velocity.x = 0.0
	# The final column contains two 16x16 poses; the upper one is the idle shell.
	enemy.sprite.flip_v = enemy.get("shell_upside_down")
	enemy.sprite.vframes = 2
	enemy.sprite.frame = 4
	enemy.sprite.position = Vector2(0, 2)


func process_physics(delta: float) -> BaseState:
	super.process_physics(delta)
	# ShellMoving inherits the terrain behavior, but never wakes while rolling.
	if walk_speed != 0.0:
		return null
	wake_ticks_remaining -= 1
	if wake_ticks_remaining <= 0:
		var enemy := entity as BaseEnemy
		var walking = enemy.get_node("StateMachine/Walking")
		walking.initial_direction = 1 if GameHandler.animation_clock.tick_count % 2 == 0 else -1
		# Restore the full-height sheet before Walking samples the shared phase.
		enemy.set("shell_upside_down", false)
		enemy.sprite.flip_v = false
		enemy.sprite.frame = 0
		enemy.sprite.vframes = 1
		enemy.sprite.position = Vector2(0, -8)
		return walking
	if wake_ticks_remaining <= WARNING_TICKS:
		entity.sprite.frame = 9 if GameHandler.animation_clock.tick_count & 8 == 0 else 4
	return null

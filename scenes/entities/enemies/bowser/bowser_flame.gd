class_name BowserFlame
extends BaseEnemy

const HORIZONTAL_STEP := 320  # 1.25 pixels in 1/256-pixel units.

var target_world_y := 0.0
var _x_fraction := 0


func _physics_process(delta: float) -> void:
	if is_shutdown or gameplay_suspended or activity_suspended:
		return
	var step := _x_fraction - HORIZONTAL_STEP
	_x_fraction = step & 255
	body.position.x += step >> 8
	body.global_position.y = move_toward(body.global_position.y, target_world_y, 1.0)
	sprite.frame = (GameHandler.animation_clock.tick_count >> 1) & 1
	super(delta)


func _can_hurt_player() -> bool:
	return true


func _can_stomp(_player: BasePlayer) -> bool:
	return false


func _blocks_enemy_contact() -> bool:
	return false


func fireball_box_origin_x(_bounds: Rect2) -> float:
	return body.global_position.x


func is_outside_horizontal_cleanup(left: float, right: float) -> bool:
	return body.global_position.x < left - 72.0 or body.global_position.x > right + 72.0

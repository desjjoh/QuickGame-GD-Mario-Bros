extends EntityState
## Shared patrol movement for enemies with a BaseEnemy terrain body.

const TERRAIN_WALK := preload("res://scenes/components/motion/terrain_walk.gd")

@export var walk_speed := 30.0
@export var gravity := 61.0 / 256.0 * 60.0 * 60.0
@export var fall_speed_limit := 180.0
@export_enum("Left:-1", "Right:1") var initial_direction: int = -1
## Artwork faces left by default; symmetric enemies can leave this disabled.
@export var face_movement: bool = false

var _direction: int


func enter() -> void:
	_direction = initial_direction
	_update_facing()
	(entity as BaseEnemy).enemy_contact.connect(_on_enemy_contact)


func exit() -> void:
	(entity as BaseEnemy).enemy_contact.disconnect(_on_enemy_contact)


func process_physics(delta: float) -> BaseState:
	_move_with_horizontal_speed(delta, walk_speed * _direction)
	return null


func _move_with_horizontal_speed(delta: float, horizontal_speed: float) -> void:
	var enemy := entity as BaseEnemy
	var body := enemy.body
	var hit_wall := TERRAIN_WALK.step(body, horizontal_speed)
	body.velocity.y = minf(body.velocity.y + gravity * delta, fall_speed_limit)
	if hit_wall:
		_turn_around()


func _turn_around() -> void:
	_direction = -_direction
	_update_facing()


func _update_facing() -> void:
	if face_movement:
		entity.sprite.flip_h = _direction > 0


func _on_enemy_contact(_other: BaseEnemy) -> void:
	_turn_around()

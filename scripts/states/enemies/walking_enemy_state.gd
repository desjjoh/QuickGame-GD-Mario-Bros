extends EntityState
## Shared patrol movement for enemies with a BaseEnemy terrain body.

@export var walk_speed := 30.0
@export var gravity := 61.0 / 256.0 * 60.0 * 60.0
@export var fall_speed_limit := 180.0
@export_enum("Left:-1", "Right:1") var initial_direction: int = -1

var _direction: int


func enter() -> void:
	_direction = initial_direction
	(entity as BaseEnemy).enemy_contact.connect(_turn_around)


func exit() -> void:
	(entity as BaseEnemy).enemy_contact.disconnect(_turn_around)


func process_physics(delta: float) -> BaseState:
	var enemy := entity as BaseEnemy
	var body := enemy.body
	body.velocity.x = walk_speed * _direction
	body.move_and_slide()
	body.velocity.y = minf(body.velocity.y + gravity * delta, fall_speed_limit)
	if body.is_on_wall():
		_turn_around()
	return null


func _turn_around() -> void:
	_direction = -_direction

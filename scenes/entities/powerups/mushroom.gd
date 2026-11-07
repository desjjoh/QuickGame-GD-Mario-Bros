class_name Mushroom
extends PowerUp
## Walks along terrain, falls off edges, and turns on wall contact.

@export var walk_speed := 60.0
# NES downward force $3d in 8-bit fractions, converted at nominal 60 Hz.
@export var gravity := 61.0 / 256.0 * 60.0 * 60.0
@export var fall_speed_limit := 300.0

var _direction := 1.0

@onready var body: CharacterBody2D = $Body


func _ready() -> void:
	super()
	$Body/BlockHitReceiver.hit_received.connect(_on_block_hit)
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevel:
		ancestor = ancestor.get_parent()
	var level := ancestor as BaseLevel
	if level != null and is_instance_valid(level.player):
		# Mario and the terrain share a physics layer.
		body.add_collision_exception_with(level.player.body)


func _advance_available(delta: float) -> void:
	body.velocity.x = walk_speed * _direction
	body.move_and_slide()
	body.velocity.y = minf(body.velocity.y + gravity * delta, fall_speed_limit)
	if body.is_on_wall():
		_direction = -_direction


func _on_block_hit(hit: EntityHit) -> void:
	if _removing or is_queued_for_deletion() or _emergence_remaining > 0.0:
		return
	if is_shutdown or gameplay_suspended or activity_suspended:
		return
	body.velocity.y = -180.0
	var player := hit.attacker as BasePlayer
	if is_instance_valid(player):
		_direction = -1.0 if body.global_position.x < player.body.global_position.x else 1.0
	else:
		_direction = -_direction
	body.velocity.x = walk_speed * _direction

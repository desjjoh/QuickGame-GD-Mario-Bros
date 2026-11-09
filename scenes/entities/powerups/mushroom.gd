class_name Mushroom
extends PowerUp
## Walks along terrain, falls off edges, and turns on wall contact.

const BLOCK_LAUNCH_SPEED := -180.0
const TERRAIN_WALK := preload("res://scenes/components/motion/terrain_walk.gd")

@export var walk_speed := 60.0
# NES downward force $3d in 8-bit fractions, converted at nominal 60 Hz.
@export var gravity := 61.0 / 256.0 * 60.0 * 60.0
@export var fall_speed_limit := 300.0

var _direction := 1.0
var _launch_presentation := (
	preload("res://scenes/components/presentation/block_launch_presentation.gd").new()
)

@onready var body: CharacterBody2D = $Body


func _ready() -> void:
	super()
	$Body/BlockHitReceiver.hit_handler = _on_block_hit
	var level := BaseLevel.containing(self)
	if level != null:
		level.ignore_player_body(body)


func _advance_available(delta: float) -> void:
	var holding := _launch_presentation.is_holding()
	if holding:
		if _launch_presentation.is_hit_tick():
			return
		# Resume walking on the first update while holding the lifted height.
		body.velocity.y = 0.0
	var hit_wall := TERRAIN_WALK.step(body, walk_speed * _direction)
	if holding:
		body.velocity.y = BLOCK_LAUNCH_SPEED
		_launch_presentation.reveal(sprite, _launch_presentation.original_position)
	else:
		body.velocity.y = minf(body.velocity.y + gravity * delta, fall_speed_limit)
	if hit_wall:
		_direction = -_direction


func _on_block_hit(hit: EntityHit) -> bool:
	if _removing or is_queued_for_deletion() or _emergence_remaining > 0.0:
		return false
	if is_shutdown or gameplay_suspended or activity_suspended:
		return false
	body.position.y -= 2.0
	_launch_presentation.capture(sprite)
	body.reset_physics_interpolation()
	body.velocity.y = BLOCK_LAUNCH_SPEED
	var player := hit.attacker as BasePlayer
	if is_instance_valid(player):
		_direction = -1.0 if body.global_position.x < player.body.global_position.x else 1.0
	else:
		_direction = -_direction
	body.velocity.x = walk_speed * _direction
	return true

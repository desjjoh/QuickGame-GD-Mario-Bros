class_name PlayerFlagpoleEndingState
extends PlayerClimbState
## Scripted intent uses the same climb/movement components as ordinary states.

enum Phase { DESCEND, DISMOUNT, WALK }
signal endpoint_reached
@export var walk_animation_name: StringName = &"walk"
@export var walk_cadence: WalkAnimationComponent
var phase: Phase = Phase.DESCEND
var source: FlagpoleEntity
var endpoint: Vector2
var stop_y: float
var _hold_ticks: int = 0


func configure(pole: FlagpoleEntity, target: Vector2) -> void:
	source = pole
	endpoint = target
	phase = Phase.DESCEND


func enter() -> void:
	var player := get_player()
	player.climbing.attach(player, source)
	player.climbing.place_on_side(player, -1.0)
	stop_y = maxf(player.body.global_position.y, source.climb_bottom.global_position.y - 2.0)
	player.run_action.apply(player.motion_values, false)
	player.run_action.remaining_ticks = 0
	player.run_action.running_history = false
	player.motion_values.remove_modifier(&"ground_neutral")
	super()


func get_movement_axis() -> Vector2:
	return (
		Vector2.DOWN
		if phase == Phase.DESCEND and get_player().body.global_position.y < stop_y
		else Vector2.ZERO
	)


func begin_dismount() -> void:
	if phase != Phase.DESCEND:
		return
	phase = Phase.DISMOUNT
	get_player().climbing.place_on_side(get_player(), 1.0)
	_hold_ticks = 24


func process_physics(delta: float) -> BaseState:
	var player := get_player()
	if phase == Phase.DESCEND:
		super.process_physics(delta)
		if player.body.global_position.y >= stop_y:
			player.body.global_position.y = stop_y
			player.body.velocity = Vector2.ZERO
		return null
	if phase == Phase.DISMOUNT:
		player.body.velocity = Vector2.ZERO
		player.animation_player.seek(0.0, true)
		player.animation_player.pause()
		_hold_ticks -= 1
		if _hold_ticks > 0:
			return null
		# The reference's next four-pixel outward nudge loses shaft contact.
		player.body.global_position.x += 4.0
		player.climbing.detach(player)
		player.body.reset_physics_interpolation()
		phase = Phase.WALK
		_play_animation(walk_animation_name)
	# Walking applies the ordinary walk profile, never Run or player input.
	player.horizontal_movement.apply(player.body, player.motion_values, 1.0, delta)
	player.face_direction(1.0)
	player.gravity_component.apply(player.motion_values, delta)
	player.move_body()
	if walk_cadence != null:
		walk_cadence.apply(player.animation_player, player.body.velocity.x)
	if player.body.global_position.x >= endpoint.x:
		player.body.global_position.x = endpoint.x
		player.body.velocity = Vector2.ZERO
		endpoint_reached.emit()
	return null

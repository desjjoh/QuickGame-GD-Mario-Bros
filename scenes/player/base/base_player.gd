class_name BasePlayer
extends BaseEntity

## Player foundation. States coordinate motion, actions, and presentation.
## Use body.global_position for the moving player's world position.

signal death_presentation_finished

var is_dead: bool = false
var _death_finished: bool = false
const STOMP_CHAIN_POINTS := [100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000]
var stomp_chain := 0
var last_enemy_stomp_tick := -1
var scripted_motion_step: Callable
const ARRIVAL_CONTROL_TICKS := 17
var arrival_control_ticks_remaining: int = 0
var _floor_sample_tick := -1
var _grounded_at_tick_start := false

@export_group("Transitions")
@export var climb_state: PlayerClimbState
@export var death_state: PlayerState
@export var pipe_enter_state: PlayerPipeEnterState

@export_group("Ceiling Response")
@export var ceiling_bump_sound: AudioStream
@export var ceiling_bump_cue: StringName
@export var ceiling_bump_speed: float = 3.75

@onready var climbing: ClimbingComponent = $Motion/Climbing
@onready var bonk_action: BonkAction = $Actions/Bonk
@onready var body: CharacterBody2D = $Body
@onready var collision_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var enemy_hurtbox := get_node_or_null("Body/EnemyHurtbox") as Area2D
@onready var horizontal_movement: HorizontalMovementComponent = $Motion/HorizontalMovement
@onready var run_action: RunAction = $Actions/Run
@onready var slide_action: SlideAction = $Actions/Slide
@onready var motion_values: MotionValues = $Motion
@onready var vertical_movement: VerticalMovementComponent = $Motion/VerticalMovement
@onready var jump_action: JumpAction = $Actions/Jump
@onready var air_movement: AirMovementComponent = $Motion/AirMovement
@onready var corner_correction: CornerCorrectionComponent = $Motion/CornerCorrection


## Optional level-owned starting configuration, supplied before tree entry.
func configure_start(_configuration: Resource) -> void:
	pass


## Area initialization resets transient posture without replacing the player.
func on_area_arrival() -> void:
	clear_arrival_control_lock()
	vertical_movement.reset_fraction()


func get_movement_axis() -> Vector2:
	return ControllerHandler.get_axis()


func get_head_position() -> Vector2:
	var shape := collision_shape.shape as RectangleShape2D
	return Vector2(body.global_position.x, collision_shape.global_position.y - shape.size.y / 2.0)


func get_side_probe_heights() -> PackedFloat32Array:
	return PackedFloat32Array([climbing.capture_probe_offset_y])


func get_climb_query_bounds() -> Rect2:
	return collision_shape.global_transform * collision_shape.shape.get_rect()


func get_effects_parent() -> Node2D:
	return body


func _ready() -> void:
	# Actors sample the player's current position after player movement.
	process_physics_priority = -1
	jump_action.reset_falling_gravity()
	jump_action.jumped.connect(_on_jump_started)
	super()


func _physics_process(delta: float) -> void:
	_floor_sample_tick = Engine.get_physics_frames()
	_grounded_at_tick_start = body.is_on_floor()
	if arrival_control_ticks_remaining > 0 and state_machine.current_state is PlayerTransportState:
		_advance_arrival_control_lock()
		return
	if scripted_motion_step.is_valid() and not is_shutdown and not is_dead:
		if not gameplay_suspended and not activity_suspended:
			scripted_motion_step.call(delta)
		return
	var before := body.global_position
	if not is_shutdown and not is_dead:
		run_action.advance_timer()
		_try_attach_climbable(before, before, false)
	super(delta)
	if not is_shutdown and not is_dead:
		# Catch actual movement after state integration, including the tick we land.
		_try_attach_climbable(before, body.global_position)
	_advance_arrival_control_lock()


func was_grounded_at_tick_start() -> bool:
	if _floor_sample_tick == Engine.get_physics_frames():
		return _grounded_at_tick_start
	return body.is_on_floor()


func _advance_arrival_control_lock() -> void:
	if not is_shutdown and not is_dead and not gameplay_suspended and not activity_suspended:
		if arrival_control_ticks_remaining > 0:
			arrival_control_ticks_remaining -= 1
			if arrival_control_ticks_remaining == 0:
				_sync_controller_input()


## AreaTransport arms this at placement, before any exit presentation advances.
func begin_arrival_control_lock() -> void:
	if is_shutdown or is_dead:
		return
	arrival_control_ticks_remaining = ARRIVAL_CONTROL_TICKS
	_sync_controller_input()


func clear_arrival_control_lock() -> void:
	arrival_control_ticks_remaining = 0
	_sync_controller_input()


func shutdown() -> void:
	arrival_control_ticks_remaining = 0
	super.shutdown()


## Called only after an enemy accepts a stomp, including nonterminal shell stops.
func award_enemy_stomp(enemy: BaseEnemy, world_position: Vector2) -> void:
	if stomp_chain < STOMP_CHAIN_POINTS.size():
		enemy.award_score(STOMP_CHAIN_POINTS[stomp_chain], world_position)
	else:
		enemy.award_extra_life(world_position)
	stomp_chain = mini(stomp_chain + 1, STOMP_CHAIN_POINTS.size())


## Reference score controls 3..10, then clamped to repeated 1-Ups.
func award_shell_kick(enemy: BaseEnemy, world_position: Vector2, interval: int) -> void:
	const KICK_POINTS := [400, 500, 800, 1000, 2000, 4000, 5000, 8000]
	if interval < 3:
		enemy.award_score([8000, 1000, 500][maxi(interval, 0)], world_position)
	elif stomp_chain < KICK_POINTS.size():
		enemy.award_score(KICK_POINTS[stomp_chain], world_position)
	else:
		enemy.award_extra_life(world_position)


func advance_scripted_walk(direction: float, delta: float) -> void:
	horizontal_movement.apply(body, motion_values, direction, delta)
	face_direction(direction)
	vertical_movement.apply_gravity(motion_values, delta)
	move_body()
	update_scripted_walk_animation()


func update_scripted_walk_animation() -> void:
	pass


func _try_attach_climbable(from_feet: Vector2, to_feet: Vector2, after_motion: bool = true) -> void:
	if climb_state == null or state_machine.current_state == climb_state:
		return
	var current := state_machine.current_state as PlayerState
	if current == null or not current.controller_controls_available():
		return
	var surface := climbing.find_surface(self, from_feet, to_feet, after_motion)
	if surface == null:
		return
	# The state transition lets Jump/Slide clean up their existing modifiers.
	climbing.attach(self, surface)
	if not state_machine.change_state(climb_state):
		climbing.detach(self)


func _on_jump_started() -> void:
	vertical_movement.reset_fraction(body)
	var sound := jump_action.sound_effect
	if sound == null:
		sound = SoundHandler.get_sound(jump_action.sound_cue)
	play_sound_effect(sound)


## Accumulated placement/recovery X excluded from camera progress, not from world position.
var camera_correction_x: float = 0.0


func move_body(gravity_after_motion: bool = false) -> void:
	var delta := get_physics_process_delta_time()
	var vertical_speed := body.velocity.y
	var rising := vertical_speed < 0.0
	var next_vertical_speed := vertical_speed
	if gravity_after_motion:
		next_vertical_speed = vertical_movement.prepare_step(motion_values, delta)
	var previous_position := body.global_position
	var horizontal_speed := body.velocity.x
	var corrected_landing := corner_correction.prepare(body, collision_shape, delta, vertical_speed)
	var intended_x := horizontal_speed * delta
	var prepared_x := body.global_position.x - previous_position.x
	camera_correction_x += prepared_x - (intended_x if corrected_landing else 0.0)
	var before_slide_x := body.global_position.x
	if corrected_landing:
		# The correction already consumed this tick's horizontal displacement.
		body.velocity.x = 0.0
		body.velocity.y = maxf(body.velocity.y, 0.0)
	body.move_and_slide()
	if corrected_landing:
		# Commit the floor contact even on ticks with no downward sweep.
		body.apply_floor_snap()
	var slide_x := body.global_position.x - before_slide_x
	var requested_x := 0.0 if corrected_landing else intended_x
	var movement_x := clampf(slide_x, minf(0.0, requested_x), maxf(0.0, requested_x))
	if (
		is_zero_approx(body.velocity.x)
		or (body.is_on_wall() and horizontal_speed * body.get_wall_normal().x < 0.0)
	):
		movement_x = 0.0
	camera_correction_x += slide_x - movement_x
	if body.is_on_floor():
		stomp_chain = 0
	if gravity_after_motion:
		# Position uses the current speed; gravity prepares the following tick.
		# Landing and ceiling response retain authority over the resulting speed.
		vertical_movement.finish_step(motion_values, next_vertical_speed)
	if corrected_landing:
		body.velocity.x = horizontal_speed
	# ImpedePlayerMove stops momentum into solid sides. Godot can retain
	# velocity at a floor/wall contact even when displacement is blocked.
	if body.is_on_wall() and body.velocity.x * body.get_wall_normal().x < 0.0:
		body.velocity.x = 0.0
	var hidden_hit := rising and bonk_action.deliver_hidden(self, previous_position)
	if rising and (hidden_hit or body.is_on_ceiling()):
		if not hidden_hit:
			bonk_action.deliver(self)
		respond_to_ceiling()


## Shared bonk motion/audio after the caller delivers the appropriate head hit.
func respond_to_ceiling() -> void:
	body.velocity.y = (
		ceiling_bump_speed
		if is_nan(bonk_action.response_velocity_y)
		else bonk_action.response_velocity_y
	)
	# Shattering retains upward speed and the held-jump gravity selection.
	if body.velocity.y >= 0.0:
		jump_action.update(motion_values, false)
	# Shatter itself has no bump pulse; a subsequent solid marker contact does.
	if bonk_action.suppress_ceiling_sound:
		return
	var sound := ceiling_bump_sound
	if sound is AudioStreamWAV:
		# One-shot playback without trusting embedded WAV loop metadata.
		sound = SoundHandler.one_shot_copy(sound)
	if sound == null:
		sound = SoundHandler.get_sound(ceiling_bump_cue)
	play_sound_effect(sound)


func face_direction(direction: float) -> void:
	if sprite == null or is_zero_approx(direction):
		return
	sprite.flip_h = direction < 0.0
	if state_machine.current_state != null:
		state_machine.current_state.apply_sprite_offset()


func begin_death(present: bool = false) -> void:
	if is_dead or is_shutdown:
		return
	stomp_chain = 0
	is_dead = true
	arrival_control_ticks_remaining = 0
	state_machine.stop(false)
	if is_shutdown:
		return
	if ControllerHandler.input_received.is_connected(state_machine.process_input):
		ControllerHandler.input_received.disconnect(state_machine.process_input)
	body.velocity = Vector2.ZERO
	body.collision_layer = 0
	body.collision_mask = 0
	jump_action.active = false
	if is_instance_valid(_active_sound_effect):
		_active_sound_effect.stop()
	if present and death_state != null:
		death_state.controls_enabled = false
		death_state.input_enabled = false
		if state_machine.change_state(death_state):
			return
	finish_death()


func finish_death() -> void:
	if not is_dead or _death_finished or is_shutdown:
		return
	_death_finished = true
	death_presentation_finished.emit()


func death_envelope_top() -> float:
	# Stable authored collision envelope; independent of animation frames.
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		return collision_shape.to_global(Vector2(0, -rectangle.size.y / 2.0)).y
	return body.global_position.y


func can_read_controller_input() -> bool:
	return (
		not is_dead and arrival_control_ticks_remaining == 0 and super.can_read_controller_input()
	)


## Ordinary damage; lethal level hazards continue to call BaseLevel.on_death directly.
func receive_damage(_source: BaseEntity = null) -> bool:
	if is_dead or is_shutdown or gameplay_suspended:
		return false
	var level := BaseLevel.containing(self)
	return level.on_death(self, true) if level != null else false

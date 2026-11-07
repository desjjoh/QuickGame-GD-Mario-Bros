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
@onready var gravity_component: GravityComponent = $Motion/Gravity
@onready var jump_action: JumpAction = $Actions/Jump
@onready var air_movement: AirMovementComponent = $Motion/AirMovement
@onready var corner_correction: CornerCorrectionComponent = $Motion/CornerCorrection


func get_effects_parent() -> Node2D:
	return body


func _ready() -> void:
	jump_action.reset_falling_gravity()
	jump_action.jumped.connect(_on_jump_started)
	super()


func _physics_process(delta: float) -> void:
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
	gravity_component.apply(motion_values, delta)
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
	var sound := jump_action.sound_effect
	if sound == null:
		sound = SoundHandler.get_sound(jump_action.sound_cue)
	play_sound_effect(sound)


func move_body(gravity_after_motion: bool = false) -> void:
	var next_vertical_speed := body.velocity.y
	if gravity_after_motion:
		next_vertical_speed = gravity_component.vertical_speed_after(
			motion_values, get_physics_process_delta_time()
		)
	var rising := body.velocity.y < 0.0
	var previous_position := body.global_position
	var horizontal_speed := body.velocity.x
	var corrected_landing := corner_correction.prepare(
		body, collision_shape, get_physics_process_delta_time()
	)
	if corrected_landing:
		# The correction already consumed this tick's horizontal displacement.
		body.velocity.x = 0.0
	body.move_and_slide()
	if body.is_on_floor():
		stomp_chain = 0
	if gravity_after_motion:
		# Position uses the current speed; gravity prepares the following tick.
		# Landing and ceiling response retain authority over the resulting speed.
		body.velocity.y = 0.0 if body.is_on_floor() else next_vertical_speed
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
		body.velocity.y = ceiling_bump_speed
		jump_action.update(motion_values, false)
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
	return not is_dead and super.can_read_controller_input()

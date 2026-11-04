class_name BasePlayer
extends BaseEntity

const AudioMix = preload("res://scripts/audio/sound_effect_mix.gd")
## Player foundation. States coordinate motion, actions, and presentation.
## Use body.global_position for the moving player's world position.

signal death_presentation_finished

var is_dead: bool = false
var _death_finished: bool = false

@export_group("Transitions")
@export var death_state: PlayerState
@export var pipe_enter_state: PlayerPipeEnterState

@export_group("Ceiling Response")
@export var ceiling_bump_sound: AudioStream
@export var ceiling_bump_speed: float = 3.75

@onready var bonk_action: BonkAction = $Actions/Bonk
@onready var body: CharacterBody2D = $Body
@onready var collision_shape: CollisionShape2D = $Body/CollisionShape2D
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
	jump_action.jumped.connect(_on_jump_started)
	super()


func _physics_process(delta: float) -> void:
	if not is_shutdown and not is_dead:
		run_action.advance_timer()
	super(delta)


func _on_jump_started() -> void:
	play_sound_effect(jump_action.sound_effect)


func move_body() -> void:
	var rising := body.velocity.y < 0.0
	var horizontal_speed := body.velocity.x
	var corrected_landing := corner_correction.prepare(
		body, collision_shape, get_physics_process_delta_time()
	)
	if corrected_landing:
		# The correction already consumed this tick's horizontal displacement.
		body.velocity.x = 0.0
	body.move_and_slide()
	if corrected_landing:
		body.velocity.x = horizontal_speed
	if rising and body.is_on_ceiling():
		bonk_action.deliver(self)
		body.velocity.y = ceiling_bump_speed
		jump_action.update(motion_values, false)
		var sound := ceiling_bump_sound
		if sound is AudioStreamWAV:
			# One-shot playback without trusting embedded WAV loop metadata.
			sound = AudioMix.one_shot_copy(sound)
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

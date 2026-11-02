class_name BasePlayer
extends BaseEntity
## Player foundation. States coordinate motion, actions, and presentation.
## Use body.global_position for the moving player's world position.

@export_group("Ceiling Response")
@export var ceiling_bump_sound: AudioStream
@export var ceiling_bump_speed: float = 3.75

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


func _on_jump_started() -> void:
	play_sound_effect(jump_action.sound_effect)


func move_body() -> void:
	var rising := body.velocity.y < 0.0
	var horizontal_speed := body.velocity.x
	var corrected_landing := corner_correction.prepare(body, collision_shape, get_physics_process_delta_time())
	if corrected_landing:
		# The correction already consumed this tick's horizontal displacement.
		body.velocity.x = 0.0
	body.move_and_slide()
	if corrected_landing:
		body.velocity.x = horizontal_speed
	if rising and body.is_on_ceiling():
		body.velocity.y = ceiling_bump_speed
		jump_action.update(motion_values, false)
		var sound := ceiling_bump_sound
		if sound is AudioStreamWAV:
			# One-shot playback without trusting embedded WAV loop metadata.
			sound = sound.duplicate()
			(sound as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		play_sound_effect(sound)


func face_direction(direction: float) -> void:
	if sprite == null or is_zero_approx(direction):
		return
	sprite.flip_h = direction < 0.0
	if state_machine.current_state != null:
		state_machine.current_state.apply_sprite_offset()


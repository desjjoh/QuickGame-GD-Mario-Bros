class_name Mario
extends BasePlayer
## Concrete player character with its own states and animation cadence.

@export var small_form: MarioForm = MarioFormPresentation.SMALL
@export var super_form: MarioForm = MarioFormPresentation.SUPER
@export var starting_form: MarioForm = MarioFormPresentation.SMALL
@onready var form_controller: MarioFormController = $Status/Form
@onready var form_presentation: MarioFormPresentation = $Presentation/FormPresentation
@onready var damage: MarioDamage = $Status/Damage


func receive_damage(source: BaseEntity = null) -> bool:
	if (
		is_dead
		or is_shutdown
		or gameplay_suspended
		or damage.is_protected()
		or form_presentation.active
	):
		return false
	if form_controller.current_form == super_form:
		if not shrink():
			return false
		damage.begin()
		play_sound_effect(SoundHandler.get_sound(&"injury"))
		return true
	return super.receive_damage(source)


func grow() -> bool:
	return form_presentation.begin(false)


func shrink() -> bool:
	return form_presentation.begin(true)


func begin_death(present: bool = false) -> void:
	form_presentation.cancel()
	damage.clear()
	super.begin_death(present)


func shutdown() -> void:
	if is_instance_valid(form_presentation):
		form_presentation.cancel()
	if is_instance_valid(damage):
		damage.clear()
	super.shutdown()


func configure_start(configuration: Resource) -> void:
	if configuration is MarioForm:
		starting_form = configuration


func _ready() -> void:
	var form := starting_form
	if form == null or form == MarioFormPresentation.SMALL:
		form = small_form
	elif form == MarioFormPresentation.SUPER:
		form = super_form
	form_controller.configure(self, form)
	super._ready()


@onready var walk_animation: WalkAnimationComponent = $Presentation/WalkAnimation


func update_scripted_walk_animation() -> void:
	if animation_player.current_animation != &"walk":
		animation_player.play(&"walk")
	walk_animation.apply(animation_player, body.velocity.x)


@onready var terrain: MarioTerrain = $Motion/MarioTerrain


func _physics_process(delta: float) -> void:
	if form_presentation.blocks_actor_motion():
		return
	var state := state_machine.current_state as PlayerState
	if state != null and not is_dead:
		if scripted_motion_step.is_valid() or state == climb_state:
			form_controller.set_crouched(false)
		elif state.controller_controls_available() and body.is_on_floor():
			form_controller.set_crouched(
				(
					form_controller.current_form.can_crouch
					and ControllerHandler.input_down > 0.5
					and ControllerHandler.input_left == 0.0
					and ControllerHandler.input_right == 0.0
				)
			)
	super._physics_process(delta)
	form_controller.refresh_posture_art()


func get_movement_axis() -> Vector2:
	var axis := super.get_movement_axis()
	if (
		body.is_on_floor()
		and ControllerHandler.input_down > 0.5
		and (ControllerHandler.input_left > 0.0 or ControllerHandler.input_right > 0.0)
	):
		return Vector2.ZERO
	return axis


func get_head_position() -> Vector2:
	if (
		form_controller.current_form != null
		and form_controller.current_form.can_crouch
		and not is_dead
	):
		return (
			body.global_position
			+ (
				MarioTerrain.SHORT_HEAD
				if form_controller.is_crouched
				else MarioTerrain.STANDING_HEAD
			)
		)
	return super.get_head_position()


func move_body(gravity_after_motion: bool = false) -> void:
	var before := body.global_position
	var rising := body.velocity.y < 0.0
	super.move_body(gravity_after_motion)
	if form_controller.current_form.can_crouch and not is_dead:
		var before_correction_x := body.global_position.x
		terrain.resolve(self, before, rising, form_controller.is_crouched)
		camera_correction_x += body.global_position.x - before_correction_x
	terrain.collect_coins(
		self, not form_controller.current_form.can_crouch or form_controller.is_crouched
	)


func get_side_probe_heights() -> PackedFloat32Array:
	if form_controller.current_form.can_crouch and not form_controller.is_crouched:
		return PackedFloat32Array(
			[climbing.capture_probe_offset_y - 16.0, climbing.capture_probe_offset_y]
		)
	return super.get_side_probe_heights()


func get_climb_query_bounds() -> Rect2:
	if form_controller.current_form.can_crouch and not form_controller.is_crouched:
		return Rect2(body.global_position + Vector2(-6, -24), Vector2(11, 24))
	return super.get_climb_query_bounds()


func on_area_arrival() -> void:
	super.on_area_arrival()
	form_presentation.cancel()
	damage.apply_visibility()
	form_controller.set_crouched(false)

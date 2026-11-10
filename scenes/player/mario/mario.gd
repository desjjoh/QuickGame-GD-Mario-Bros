class_name Mario
extends BasePlayer
## Concrete player character with its own states and animation cadence.

const FIREBALL_LAUNCHER = preload("res://scripts/player/fireball_launcher.gd")

@export var small_form: MarioForm = MarioFormPresentation.SMALL
@export var super_form: MarioForm = MarioFormPresentation.SUPER
@export var fire_form: MarioForm = MarioFormPresentation.FIRE
@export var starting_form: MarioForm = MarioFormPresentation.SMALL
## Includes fireballs in their burst animation. Zero disables shooting.
@export_range(0, 16) var max_fireballs: int = 2
@onready var form_controller: MarioFormController = $Status/Form
@onready var form_presentation: MarioFormPresentation = $Presentation/FormPresentation
@onready var damage: MarioDamage = $Status/Damage
@onready var starman: MarioStarman = $Status/Starman
@onready var _throw_pose: FireThrowPose = $Body/Sprite2D/ThrowPose
var _fireballs := FIREBALL_LAUNCHER.new()
var _throw_timer_reload := 7
var _floor_supported := false
var _floor_position := Vector2.INF
var _lift_support: MovingLift


func receive_damage(source: BaseEntity = null) -> bool:
	if (
		is_dead
		or is_shutdown
		or gameplay_suspended
		or damage.is_protected()
		or starman.is_active()
		or form_presentation.active
	):
		return false
	if form_controller.current_form in [super_form, fire_form]:
		if not shrink():
			return false
		damage.begin()
		play_sound_effect(SoundHandler.get_sound(&"injury"))
		return true
	return super.receive_damage(source)


func grow() -> bool:
	return form_presentation.begin(false)


func ignite() -> bool:
	return form_presentation.begin_fire()


func shrink() -> bool:
	if not form_presentation.begin(true):
		return false
	_throw_pose.clear()
	return true


func begin_death(present: bool = false) -> void:
	starman.clear()
	_throw_pose.clear()
	form_presentation.cancel()
	damage.clear()
	super.begin_death(present)


func shutdown() -> void:
	if is_instance_valid(starman):
		starman.clear()
	if is_instance_valid(_throw_pose):
		_throw_pose.clear()
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
	var active_level := GameHandler.current_level
	var gameplay_spawn := (
		is_instance_valid(active_level)
		and BaseLevel.containing(self) == active_level
		and GameHandler.flow != GameHandler.GameFlow.TITLE
	)
	if gameplay_spawn and GameHandler.flow == GameHandler.GameFlow.COMPLETING:
		match GameHandler.player_status.powerup_form:
			PlayerStatus.PowerupForm.SMALL:
				form = MarioFormPresentation.SMALL
			PlayerStatus.PowerupForm.SUPER:
				form = MarioFormPresentation.SUPER
			PlayerStatus.PowerupForm.FIRE:
				form = MarioFormPresentation.FIRE
	if form == null or form == MarioFormPresentation.SMALL:
		form = small_form
	elif form == MarioFormPresentation.SUPER:
		form = super_form
	elif form == MarioFormPresentation.FIRE:
		form = fire_form
	form_controller.configure(self, form)
	super._ready()
	if gameplay_spawn:
		if form == fire_form:
			GameHandler.set_player_form(PlayerStatus.PowerupForm.FIRE)
		elif form == super_form:
			GameHandler.set_player_form(PlayerStatus.PowerupForm.SUPER)
		else:
			GameHandler.set_player_form(PlayerStatus.PowerupForm.SMALL)


@onready var walk_animation: WalkAnimationComponent = $Presentation/WalkAnimation


func update_scripted_walk_animation() -> void:
	if animation_player.current_animation != &"walk":
		animation_player.play(&"walk")
	walk_animation.apply(animation_player, body.velocity.x)


@onready var terrain: MarioTerrain = $Motion/MarioTerrain


func _physics_process(delta: float) -> void:
	if form_presentation.blocks_actor_motion():
		_throw_pose.clear()
		return
	var grounded := has_floor_support()
	var previous_speed := body.velocity.x
	var state := state_machine.current_state as PlayerState
	var fire_pressed := (
		ControllerHandler.input_secondary_just_pressed
		and form_controller.current_form == fire_form
		and state != null
		and state.controller_controls_available()
		and not scripted_motion_step.is_valid()
	)
	if state != null and not is_dead:
		if scripted_motion_step.is_valid() or state == climb_state:
			form_controller.set_crouched(false)
		elif state.controller_controls_available() and has_floor_support():
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
	var current_state := state_machine.current_state
	if grounded and not current_state is MarioJumpState:
		_throw_timer_reload = walk_animation.get_frame_ticks(previous_speed)
	if (
		form_controller.current_form != fire_form
		or not can_read_controller_input()
		or current_state == climb_state
		or form_controller.is_crouched
		or form_presentation.active
		or scripted_motion_step.is_valid()
	):
		_throw_pose.clear()
		return
	var launched := fire_pressed and _fireballs.try_launch(self) != null
	_throw_pose.update_pose(
		_throw_timer_reload if launched else 0,
		current_state is MarioMoveState and has_floor_support(),
		not is_zero_approx(body.velocity.x) or not is_zero_approx(get_movement_axis().x)
	)


func get_movement_axis() -> Vector2:
	var axis := super.get_movement_axis()
	if (
		has_floor_support()
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
	if _uses_floor_probes():
		_floor_position = body.global_position


func has_floor_support() -> bool:
	if is_instance_valid(_lift_support) and can_contact_lift() and _lift_support.supports(self):
		return true
	# Placements and scripted motion can move the body outside the normal step.
	if _uses_floor_probes() and _floor_position == body.global_position:
		return _floor_supported
	return super.has_floor_support()


func can_contact_lift() -> bool:
	return not is_shutdown and not gameplay_suspended and _uses_floor_probes()


func land_on_lift(lift: MovingLift) -> void:
	_lift_support = lift
	body.global_position.y = lift.global_position.y
	vertical_movement.finish_step_on_support(motion_values, 0.0, true)
	stomp_chain = 0
	var jump := state_machine.current_state as MarioJumpState
	if jump != null:
		state_machine.change_state(jump.landing_state(get_movement_axis().x))


func release_lift_support(lift: MovingLift) -> void:
	if _lift_support == lift:
		_lift_support = null


func _uses_floor_probes() -> bool:
	if scripted_motion_step.is_valid() or body.collision_mask == 0 or is_dead:
		return false
	var state := state_machine.current_state
	return (
		state is MarioIdleState
		or state is MarioMoveState
		or state is MarioSlideState
		or state is MarioJumpState
	)


func _sweep_motion(delta: float, vertical_speed: float) -> void:
	if not _uses_floor_probes():
		_floor_position = Vector2.INF
		super._sweep_motion(delta, vertical_speed)
		return
	var step := MarioTerrain.FloorStep.SWEEP
	if vertical_speed >= 0.0:
		step = terrain.step_floor(self, delta)
	_floor_supported = step == MarioTerrain.FloorStep.LAND
	if step == MarioTerrain.FloorStep.SWEEP:
		_sweep_body(delta, vertical_speed, false)
		_floor_supported = vertical_speed >= 0.0 and terrain.supports_body(body)
		if _floor_supported:
			body.apply_floor_snap()
	_floor_position = body.global_position


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


func on_area_arrival(through_pipe: bool = false) -> void:
	super.on_area_arrival(through_pipe)
	_floor_position = Vector2.INF
	_lift_support = null
	if through_pipe:
		starman.clear()
	_throw_pose.clear()
	form_presentation.cancel()
	damage.apply_visibility()
	form_controller.set_crouched(false)


func on_level_end() -> void:
	starman.clear()

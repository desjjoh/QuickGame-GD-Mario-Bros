class_name MarioFormController
extends Node
## Applies instance-local presentation/contact configuration, never replaces Mario.

var current_form: MarioForm
var is_crouched := false
var presentation_owned := false
var _player: BasePlayer
var _library_template: AnimationLibrary
var _death_texture: Texture2D


func configure(player: BasePlayer, form: MarioForm) -> void:
	_player = player
	var machine := player.get_node("StateMachine") as EntityStateMachine
	var animation := player.get_node("Body/AnimationPlayer") as AnimationPlayer
	if _library_template == null:
		_library_template = animation.get_animation_library(&"")
		_death_texture = machine.get_node("Dead").sprite_texture
		for state_name in ["Idle", "Move", "Slide", "Jump", "PipeEnter", "Climb", "Dead"]:
			(machine.get_node(state_name) as BaseState).entered.connect(_apply_pose_offset)
	current_form = form
	_player.jump_action.sound_cue = form.jump_cue
	var previous_animation := animation.current_animation
	var previous_position := (
		animation.current_animation_position if previous_animation != &"" else 0.0
	)
	var textures := {
		"Idle": form.idle,
		"Move": form.walk[0],
		"Slide": form.skid,
		"Jump": form.jump,
		"PipeEnter": form.idle,
		"Climb": form.climb[0],
		"Dead": _death_texture
	}
	for state_name: String in textures:
		(machine.get_node(state_name) as BaseState).sprite_texture = textures[state_name]
	var library := AnimationLibrary.new()
	for animation_name: StringName in _library_template.get_animation_list():
		var clip := _library_template.get_animation(animation_name).duplicate(true) as Animation
		if animation_name in [&"walk", &"climb"]:
			var frames: Array[Texture2D] = form.walk if animation_name == &"walk" else form.climb
			for key in range(clip.track_get_key_count(0)):
				clip.track_set_key_value(0, key, frames[key])
		library.add_animation(animation_name, clip)
	animation.stop(true)
	animation.remove_animation_library(&"")
	animation.add_animation_library(&"", library)
	is_crouched = false
	_apply_contact_profile()
	if machine.current_state != null:
		machine.current_state.apply_presentation()
		if previous_animation != &"" and animation.has_animation(previous_animation):
			animation.play(previous_animation)
			animation.seek(previous_position, true)
	_apply_pose_offset()


func _apply_pose_offset() -> void:
	var machine := _player.get_node("StateMachine") as EntityStateMachine
	var dead := machine.current_state != null and machine.current_state.name == &"Dead"
	_player.sprite.position = Vector2(0, -7) if dead else current_form.sprite_position
	if machine.current_state != null:
		var state := machine.current_state
		if (
			dead
			or state == _player.climb_state
			or (
				state is PlayerPipeEnterState
				and (state as PlayerPipeEnterState)._direction.x != 0.0
			)
		):
			set_crouched(false)
	refresh_posture_art()


func set_crouched(value: bool) -> void:
	value = value and current_form.can_crouch
	if is_crouched == value:
		return
	is_crouched = value
	_apply_contact_profile()
	refresh_posture_art()


func _apply_contact_profile() -> void:
	var contact := _player.get_node("Body/EnemyHurtbox/CollisionShape2D") as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = (
		current_form.crouched_contact_size if is_crouched else current_form.standing_contact_size
	)
	contact.shape = shape
	(_player.get_node("Body/EnemyHurtbox") as Area2D).position = (
		current_form.crouched_contact_position
		if is_crouched
		else current_form.standing_contact_position
	)


func refresh_posture_art() -> void:
	if presentation_owned:
		return
	var state := _player.state_machine.current_state
	if state == null:
		return
	var crouch_pose := is_crouched and state.name in [&"Idle", &"Move", &"Jump", &"PipeEnter"]
	if state.name == &"Move" and not _player.body.is_on_floor():
		crouch_pose = false
	if crouch_pose:
		_player.animation_player.pause()
		_player.sprite.texture = current_form.crouch
	elif current_form.crouch != null and _player.sprite.texture == current_form.crouch:
		_player.sprite.texture = state.sprite_texture
		if state.animation_name != &"":
			_player.animation_player.play(state.animation_name)
			_player.animation_player.advance(0.0)

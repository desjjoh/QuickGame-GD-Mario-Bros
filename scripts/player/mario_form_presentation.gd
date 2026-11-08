class_name MarioFormPresentation
extends Node
## Mario owns transformation poses; the level only gates world/timer advancement.

signal finished

const SMALL: MarioForm = preload("res://assets/player/forms/small.tres")
const SUPER: MarioForm = preload("res://assets/player/forms/super.tres")
const GROWTH_POSES := [0, 1, 0, 1, 0, 1, 2, 0, 1, 2]

var active := false
var shrinking := false
var timer := 0
var pose_index := 0
var changing := false
var _cycle_finished := false
var _mario: Mario
var _level: BaseLevel
var _suspended: Array[WeakRef] = []
var _previous_machine_suspended := false
var _animation_speed := 1.0
var _visible := true
var _walk_frame := 0
var _walk_timer := 0
var _prelude_advance := false
var _closing_tick := -1
var _finish_pending := false
var _actor_restored := false
var _reset_on_visible := false


func _ready() -> void:
	_mario = get_node("../..") as Mario
	process_physics_priority = -80  # After the global clock, before actor physics.


func begin(shrink: bool) -> bool:
	if active or _mario.is_dead or _mario.is_shutdown or _mario.gameplay_suspended:
		return false
	if _mario.form_controller.current_form != (SUPER if shrink else SMALL):
		return false
	var ancestor := _mario.get_parent()
	while ancestor != null and not ancestor is BaseLevel:
		ancestor = ancestor.get_parent()
	_level = ancestor as BaseLevel
	if (
		_level == null
		or _level.is_shutdown
		or _level.death_in_progress
		or _level.completion_in_progress
		or _level.transition_in_progress
		or _level.area_transport.pending
		or is_instance_valid(_level.player_presentation)
		or _mario.scripted_motion_step.is_valid()
	):
		return false
	active = true
	shrinking = shrink
	timer = 0xff
	pose_index = 0
	changing = false
	_cycle_finished = false
	_finish_pending = false
	_actor_restored = false
	_reset_on_visible = false
	_closing_tick = -1
	_remember_walk()
	_prelude_advance = _walk_timer == 0
	_level.player_presentation = self
	_previous_machine_suspended = _mario.state_machine.gameplay_suspended
	_mario.state_machine.gameplay_suspended = true
	_animation_speed = _mario.animation_player.speed_scale
	_visible = _mario.sprite.visible
	_mario.animation_player.speed_scale = 0.0
	_mario.form_controller.presentation_owned = true
	_mario.animation_player.pause()
	if shrinking:
		_set_pose(SUPER.jump, SUPER)
	else:
		_apply_growth_normal(SMALL)
	for entity: BaseEntity in _level.find_children("*", "BaseEntity", true, false):
		if entity != _mario and not entity.gameplay_suspended:
			_suspended.append(weakref(entity))
			entity.set_gameplay_suspended(true)
	GameHandler.set_player_form(
		PlayerStatus.PowerupForm.SMALL if shrink else PlayerStatus.PowerupForm.SUPER
	)
	return true


func _physics_process(_delta: float) -> void:
	if not active:
		_walk_timer = maxi(0, _walk_timer - 1)
		_remember_walk()
		return
	if _mario.is_dead or _mario.is_shutdown or not is_instance_valid(_level) or _level.is_shutdown:
		cancel()
		return
	if _finish_pending:
		_finish()
		return
	timer -= 1
	var tick := GameHandler.animation_clock.tick_count
	if not shrinking and not changing and not _cycle_finished:
		if _prelude_advance:
			_walk_frame = (_walk_frame + 1) % 3
			_prelude_advance = false
		_apply_growth_normal(SMALL)
	if timer == (0xf0 if shrinking else 0xf8):
		var previous_offset := _mario.sprite.position
		_mario.form_controller.configure(_mario, SMALL if shrinking else SUPER)
		if _mario.sprite.position != previous_offset:
			_reset_pose_interpolation()
		_mario.animation_player.pause()
		_walk_frame = 0
		changing = true
	if changing:
		if tick % 4 == 0:
			pose_index += 1
			if pose_index == 10:
				# HandleChangeSize resets its control and draws entry zero once
				# more on the same update that clears the change-size flag.
				pose_index = 0
				changing = false
				_cycle_finished = true
				_closing_tick = tick
		_apply_pose()
	elif _cycle_finished:
		if shrinking:
			if timer != 0xc8 and not _actor_restored:
				_restore_actor_presentation()
		else:
			_apply_growth_normal(SUPER)
	if shrinking:
		_mario.sprite.visible = _visible and tick % 2 == 0
		if _mario.sprite.visible and _reset_on_visible:
			_mario.sprite.reset_physics_interpolation()
			_reset_on_visible = false
	if timer == (0xc8 if shrinking else 0xc4):
		# DonePlayerTask selects normal control for the NEXT engine tick.
		timer = 0
		_finish_pending = true
		_mario.state_machine.gameplay_suspended = true


func _remember_walk() -> void:
	if not is_instance_valid(_mario) or not is_instance_valid(_mario.form_controller):
		return
	var animation := _mario.animation_player
	if animation.current_animation != &"walk" or not animation.is_playing():
		return
	var form := _mario.form_controller.current_form
	var index := form.walk.find(_mario.sprite.texture)
	if index >= 0:
		# Supplied sheets are cyclically ordered NES frames 1, 2, 0.
		_walk_frame = (index + 1) % 3
	var duration := animation.get_animation(&"walk").length / 3.0
	var remaining := duration - fposmod(animation.current_animation_position, duration)
	var rate := absf(animation.get_playing_speed())
	if rate > 0.0:
		_walk_timer = maxi(0, ceili(remaining / rate * 60.0 - 0.0001))


func _set_pose(texture: Texture2D, form: MarioForm) -> void:
	_mario.sprite.texture = _mario.resolve_texture(texture)
	_set_pose_offset(form.sprite_position)


func _set_pose_offset(offset: Vector2) -> void:
	var changed := _mario.sprite.position != offset
	_mario.sprite.position = offset
	# Size-change textures swap instantly; their matching offsets must snap too.
	if changed:
		_reset_pose_interpolation()


func _reset_pose_interpolation() -> void:
	if shrinking:
		# A hidden sprite must be shown before its render history is reset.
		_reset_on_visible = true
	else:
		_mario.sprite.reset_physics_interpolation()


func _apply_growth_normal(form: MarioForm) -> void:
	var velocity := _mario.body.velocity.x
	var facing := -1.0 if _mario.sprite.flip_h else 1.0
	var moving := not is_zero_approx(velocity) or not is_zero_approx(_mario.get_movement_axis().x)
	var texture := form.walk[(_walk_frame + 2) % 3] if moving else form.idle
	if velocity * facing < 0.0 and absf(velocity) >= 33.75:
		texture = form.skid
	_set_pose(texture, form)


func _finish() -> void:
	var growth := not shrinking
	var airborne := not _mario.body.is_on_floor()
	var velocity := _mario.body.velocity
	cancel()
	if growth and not _mario.is_dead and not _mario.is_shutdown:
		var next_state := _mario.get_node("StateMachine/Move") as MarioMoveState
		_mario.state_machine.change_state(next_state)
		_mario.body.velocity = velocity
		if airborne:
			next_state.defer_growth_fall_step()
		_seek_reference_walk_start()
	finished.emit()


func _seek_reference_walk_start() -> void:
	if _mario.animation_player.current_animation == &"walk":
		var clip := _mario.animation_player.get_animation(&"walk")
		_mario.animation_player.seek(clip.length * 2.0 / 3.0, true)


func _apply_pose() -> void:
	var texture: Texture2D
	var offset: Vector2
	if shrinking:
		var form := SMALL if pose_index % 2 == 0 else SUPER
		texture = form.shrink_pose
		offset = form.sprite_position
	else:
		var pose: int = GROWTH_POSES[pose_index]
		texture = [SMALL.idle, SUPER.growth_intermediate, SUPER.idle][pose]
		offset = SMALL.sprite_position if pose == 0 else SUPER.sprite_position
	_mario.sprite.texture = _mario.resolve_texture(texture)
	_set_pose_offset(offset)


func _restore_actor_presentation() -> void:
	_actor_restored = true
	_mario.form_controller.presentation_owned = false
	if shrinking:
		_mario.state_machine.gameplay_suspended = _previous_machine_suspended
	_mario.animation_player.speed_scale = _animation_speed
	if _mario.state_machine.current_state != null:
		_mario.state_machine.current_state.apply_presentation()
	_seek_reference_walk_start()
	_mario.form_controller._apply_pose_offset()


## Cancellation settles the accepted target form and releases only our suspension.
func cancel() -> void:
	if not active:
		return
	active = false
	changing = false
	if is_instance_valid(_mario) and not _mario.is_shutdown:
		var target := SMALL if shrinking else SUPER
		if _mario.form_controller.current_form != target:
			_mario.form_controller.configure(_mario, target)
		if not _actor_restored:
			_restore_actor_presentation()
		_mario.sprite.visible = _visible
		_mario.state_machine.gameplay_suspended = _previous_machine_suspended
	for reference: WeakRef in _suspended:
		var entity := reference.get_ref() as BaseEntity
		if is_instance_valid(entity) and not entity.is_shutdown:
			entity.set_gameplay_suspended(false)
	_suspended.clear()
	if is_instance_valid(_level) and _level.player_presentation == self:
		_level.player_presentation = null
	_level = null


func blocks_actor_motion() -> bool:
	return (
		active
		and (
			not shrinking
			or not _cycle_finished
			or _finish_pending
			or GameHandler.animation_clock.tick_count == _closing_tick
		)
	)


func _exit_tree() -> void:
	cancel()

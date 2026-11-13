class_name Bowser
extends BaseEnemy
## The body origin is the NES front-half origin. The rear follows its facing.

const PATROL_RANGES := [33, 65, 17, 49]
const FEET_PERIOD := 32
const REAR_OFFSET := Vector2(16, 8)
const RIGHT_LIMIT := 88.0
const FACE_RIGHT := 1
const FACE_LEFT := 2
const GOOMBA_REVEAL := preload("res://assets/palettes/overworld/enemies/goomba.png")
const DEFEAT_GRAVITY := 857.8125  # 61/256 px per tick squared.

@onready var _rear_contact: Area2D = $Body/RearContact
@onready var _rear_shape: CollisionShape2D = $Body/RearContact/CollisionShape2D
@onready var _motion: MotionValues = $Motion
@onready var _vertical: VerticalMovementComponent = $Motion/VerticalMovement

var _jump_ticks := 32
var _feet_ticks := FEET_PERIOD
var _breath_ticks := 223
var _breath_index := 0
var flame_source: BowserFlameSource
var _patrol_step := 2
var _patrol_range := 0
# The initial direction flips the art, but only $01 suppresses patrol reversal.
var _direction := 0xdf
var _alternate_feet := false
var _mouth_open := false
var hit_points := 5
var _defeat_tick := -1


func _ready() -> void:
	super()
	_update_pose()


func _physics_process(delta: float) -> void:
	if (
		is_shutdown
		or gameplay_suspended
		or activity_suspended
		or (is_instance_valid(_level) and _level.completion_in_progress)
	):
		return
	if is_defeated():
		_advance_defeat(delta)
		return
	var player := _level.player if is_instance_valid(_level) else null
	var player_x := (
		floorf(player.body.global_position.x - 8.0) if is_instance_valid(player) else -INF
	)
	_advance_patrol(delta, Engine.get_physics_frames(), player_x)
	super(delta)


func _advance_patrol(delta: float, tick: int, player_x: float) -> void:
	_jump_ticks = maxi(_jump_ticks - 1, 0)
	_breath_ticks = maxi(_breath_ticks - 1, 0)
	if not _mouth_open:
		_feet_ticks -= 1
		if _feet_ticks == 0:
			_feet_ticks = FEET_PERIOD
			_alternate_feet = not _alternate_feet
		_step_horizontal(tick, player_x)
	if _jump_ticks == 1:
		body.position.y -= 1.0
		# The reference resets the speed fraction and preserves the position fraction.
		body.velocity.y = -120.0
	elif _jump_ticks == 0:
		_step_vertical(delta)
		if body.position.y >= 0.0:
			_jump_ticks = _pick_patrol_range()
	if _breath_ticks == 0:
		_mouth_open = not _mouth_open
		if _mouth_open:
			_breath_ticks = 32
		else:
			if is_instance_valid(flame_source):
				_breath_ticks = flame_source.request_breath()
			else:
				_breath_ticks = BowserFlameSource.DELAYS[_breath_index]
				_breath_index = (_breath_index + 1) % BowserFlameSource.DELAYS.size()
	_update_pose()


func _step_horizontal(tick: int, player_x: float) -> void:
	if tick % 16 == 0:
		_direction = FACE_LEFT
	if _jump_ticks > 0 and player_x > body.global_position.x:
		_direction = FACE_RIGHT
		_patrol_step = 2
		_jump_ticks = 32
		_breath_ticks = 32
		if body.position.x >= RIGHT_LIMIT:
			return
	if tick % 4 != 0:
		return
	if body.position.x == 0.0:
		_patrol_range = _pick_patrol_range()
	body.position.x += _patrol_step
	if _direction != FACE_RIGHT and absf(body.position.x) >= _patrol_range:
		_patrol_step = -1 if body.position.x >= 0.0 else 1


func _pick_patrol_range() -> int:
	return PATROL_RANGES[randi_range(0, PATROL_RANGES.size() - 1)]


func _update_pose() -> void:
	var facing_right := (_direction & 1) != 0
	var rear_x := -REAR_OFFSET.x if facing_right else REAR_OFFSET.x
	_rear_contact.position = Vector2(rear_x + 8.0, REAR_OFFSET.y + 11.5)
	sprite.position.x = minf(0.0, rear_x)
	if sprite.flip_h != facing_right:
		sprite.reset_physics_interpolation()
	sprite.flip_h = facing_right
	sprite.frame = int(_mouth_open) * 2 + int(_alternate_feet)


func _touches_player_now(player: BasePlayer) -> bool:
	return super(player) or PLAYER_CONTACT.touches(_rear_contact, player.enemy_hurtbox)


func _can_hurt_player() -> bool:
	return true


func _can_stomp(_player: BasePlayer) -> bool:
	return false


func _blocks_enemy_contact() -> bool:
	return false


func fireball_target_boxes() -> Array[Rect2]:
	return [PLAYER_CONTACT.bounds(_rear_shape), projectile_target_bounds()]


func fireball_box_origin_x(bounds: Rect2) -> float:
	return bounds.position.x


func bridge_collapse_delay() -> int:
	return _feet_ticks


func step_on_collapsing_bridge() -> void:
	_alternate_feet = not _alternate_feet
	_update_pose()


func begin_bridge_fall() -> void:
	# The NES clears both speed bytes and carries the position fraction.
	body.velocity = Vector2.ZERO


func advance_bridge_fall(delta: float, cutoff_y: float) -> bool:
	if body.global_position.y >= cutoff_y:
		queue_free()
		return true
	_step_vertical(delta)
	return false


func can_contact_fireball() -> bool:
	return super() and (not is_instance_valid(_level) or not _level.completion_in_progress)


func _accept_hit(hit: EntityHit) -> bool:
	if hit.maneuver != &"fireball":
		return false
	hit_points -= 1
	if hit_points > 0:
		return true
	mark_defeated(hit)
	if is_shutdown or is_queued_for_deletion():
		return true
	_defeat_tick = Engine.get_physics_frames()
	# Keep the contact pose on the hit tick. The revealed Goomba draws next tick.
	var origin := body.global_position
	var popup_origin := hit.fireball_target.position - Vector2(0, 2)
	if not hit.fireball_target.has_area():
		popup_origin = origin
	_motion.base_gravity = DEFEAT_GRAVITY
	_motion.base_max_fall_speed = 180.0
	body.velocity.y = -120.0
	_step_vertical(1.0 / 60.0)
	sprite.global_position.y += origin.y - body.global_position.y
	sprite.reset_physics_interpolation()
	award_score(5000, popup_origin + Vector2(8, -4), 5, true)
	SoundHandler.play_reward(&"bowser_fall")
	play_sound_effect(SoundHandler.get_sound(&"enemy_smack"))
	return true


func _advance_defeat(delta: float) -> void:
	if Engine.get_physics_frames() == _defeat_tick:
		return
	var first_reveal := not sprite.flip_v
	if first_reveal:
		sprite.texture = resolve_texture(GOOMBA_REVEAL)
		sprite.hframes = 3
		sprite.frame = 0
		sprite.flip_v = true
	var draw_y := body.global_position.y + 13.0
	_step_vertical(delta)
	sprite.global_position = Vector2(body.global_position.x, draw_y)
	if first_reveal:
		sprite.reset_physics_interpolation()


func _step_vertical(delta: float) -> void:
	var next_speed := _vertical.prepare_step(_motion, delta, global_position.y)
	# Bowser moves on the encounter's scripted height grid without a terrain sweep.
	body.position.y += body.velocity.y * delta
	_vertical.finish_step_on_support(_motion, next_speed, false)


func is_outside_horizontal_cleanup(left: float, right: float) -> bool:
	var anchor := floorf(body.global_position.x)
	var right_extension := 73.0 if left >= 73.0 else 72.0
	return anchor < left - 73.0 or anchor >= right + right_extension

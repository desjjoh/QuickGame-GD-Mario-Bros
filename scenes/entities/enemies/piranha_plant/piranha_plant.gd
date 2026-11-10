extends BaseEnemy

const TRAVEL := 24
const DWELL_TICKS := 64
const SAFE_DISTANCE := 32.0
const DEFEAT_DROP := 23
const FRAME_WIDTH := 16

var _rise := 0
var _direction := 0
var _dwell_ticks := 0


func _ready() -> void:
	super()
	DRAW_ORDER.apply(sprite, DRAW_ORDER.BEHIND_WORLD)


func _physics_process(delta: float) -> void:
	super(delta)
	if _defeated or is_shutdown or gameplay_suspended:
		return
	var tick := Engine.get_physics_frames()
	sprite.region_rect.position.x = FRAME_WIDTH if (tick & 8) == 0 else 0
	if _dwell_ticks > 0:
		_dwell_ticks -= 1
		if _dwell_ticks > 0:
			return
	if _direction == 0:
		if _rise == 0 and _player_is_near():
			return
		_direction = 1 if _rise == 0 else -1
	if tick % 2 == 0:
		return
	_rise += _direction
	body.position.y = -_rise
	body.reset_physics_interpolation()
	if _rise == 0 or _rise == TRAVEL:
		_direction = 0
		_dwell_ticks = DWELL_TICKS


func _player_is_near() -> bool:
	var player := _level.player if is_instance_valid(_level) else null
	if not is_instance_valid(player):
		return false
	# Both NES horizontal origins are eight pixels left of the centered bodies.
	return (
		absf(floorf(player.body.global_position.x) - floorf(body.global_position.x))
		<= SAFE_DISTANCE
	)


func _can_hurt_player() -> bool:
	return true


func _can_stomp(_player: BasePlayer) -> bool:
	return false


func _blocks_enemy_contact() -> bool:
	return false


func is_outside_horizontal_cleanup(left: float, _right: float) -> bool:
	# The plant stays tied to the pipe and retires just beyond the left edge.
	return floorf(body.global_position.x - 8.0) < left - 16.0


func _accept_hit(hit: EntityHit) -> bool:
	if hit.maneuver not in [&"fireball", &"star"]:
		return false
	mark_defeated(hit)
	if is_shutdown or is_queued_for_deletion():
		return true
	body.position.y += DEFEAT_DROP
	# The reference drop conceals the plant. Hide the art so the last sprite row
	# cannot stick above the pipe while the defeated actor still holds its slot.
	sprite.hide()
	award_smack_defeat(200, body.global_position.round() - Vector2(0, 4))
	return true

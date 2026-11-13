class_name FireBar
extends SpawnableEntity

enum Length { SHORT = 5, LONG = 11 }
enum Speed { STANDARD = 40, FAST = 56 }
enum Direction { CLOCKWISE = 1, COUNTERCLOCKWISE = -1 }

const ART := preload("res://assets/items/fireball.png")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
const PIVOT := Vector2i(8, 8)
const ORIGIN_OFFSET := Vector2i(4, 4)
const PHASE_MASK := 0x1fff
const MIRROR := [1, 3, 2, 0]
# Integer radii from the NES table. Each row covers a quarter of the rotation.
const RADII := [
	[0, 1, 3, 4, 5, 6, 7, 7, 8],
	[0, 3, 6, 9, 11, 13, 14, 15, 16],
	[0, 4, 9, 13, 16, 19, 22, 23, 24],
	[0, 6, 12, 18, 22, 26, 29, 31, 32],
	[0, 7, 15, 22, 28, 33, 37, 39, 40],
	[0, 9, 18, 27, 33, 39, 44, 47, 48],
	[0, 11, 21, 31, 39, 46, 51, 55, 56],
	[0, 12, 24, 36, 45, 53, 59, 62, 64],
	[0, 14, 27, 40, 50, 59, 66, 70, 72],
	[0, 15, 31, 45, 56, 66, 74, 78, 80],
	[0, 17, 34, 49, 62, 73, 81, 86, 88],
]

@export var length: Length = Length.SHORT
@export var speed: Speed = Speed.STANDARD
@export var direction: Direction = Direction.CLOCKWISE

var phase := 0
var _segments: Array[Sprite2D] = []
var _level: BaseLevel
var _area: BaseLevelArea
var _last_player_id := 0
var _last_probe_tick := -1
var _last_probe_x := 0


func _ready() -> void:
	# Sample after BaseLevel moves the camera and clamps the player.
	process_physics_priority = 105
	_level = BaseLevel.containing(self)
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevelArea:
		ancestor = ancestor.get_parent()
	_area = ancestor as BaseLevelArea
	for index in range(length + 1):
		var segment := Sprite2D.new()
		segment.texture = ART
		segment.hframes = 4
		DRAW_ORDER.apply(segment, DRAW_ORDER.ENEMY)
		$Presentation.add_child(segment)
		_segments.append(segment)
	super()
	_update_segments()
	hide()


func _physics_process(_delta: float) -> void:
	if is_shutdown or gameplay_suspended or activity_suspended or not is_instance_valid(_area):
		return
	var view := _area.get_activity_region(false).grow(-_area.activation_buffer)
	var mario := _level.player as Mario if is_instance_valid(_level) else null
	# Keep sampling while the pivot is outside the view so entry uses the previous frame.
	var probe_x := _sample_player_probe_x(mario, view)
	var origin := Vector2i(global_position.floor()) + ORIGIN_OFFSET
	visible = origin.x >= floorf(view.position.x) and origin.x < floorf(view.end.x)
	if not visible:
		return
	advance_rotation()
	_update_segments()
	if not is_instance_valid(mario) or mario.is_dead or mario.is_shutdown:
		return
	var short := (
		not mario.form_controller.current_form.can_crouch or mario.form_controller.is_crouched
	)
	if touches_player(player_feet_y(mario), short, view, probe_x):
		mario.receive_damage(self)


func get_activity_rect() -> Rect2:
	return Rect2(global_position + Vector2(ORIGIN_OFFSET), Vector2(8, 8))


func advance_rotation() -> void:
	phase = (phase + speed * direction) & PHASE_MASK
	var angle := phase >> 8
	if length == Length.LONG and angle in [8, 24]:
		phase = (phase + 256 * direction) & PHASE_MASK


func segment_offset(index: int) -> Vector2i:
	if index == 0:
		return Vector2i.ZERO
	var angle := phase >> 8
	var mirror: int = MIRROR[angle >> 3]
	var x: int = RADII[index - 1][_fold_angle(angle)]
	var y: int = RADII[index - 1][_fold_angle(angle + 8)]
	return Vector2i(x if mirror & 1 else -x, y if mirror & 2 else -y)


func _sample_player_probe_x(player: Mario, view: Rect2) -> int:
	if not is_instance_valid(player) or player.is_dead or player.is_shutdown:
		_last_player_id = 0
		return 0
	var screen_x := floori(player.body.global_position.x) - floori(view.position.x) - 4
	var tick := Engine.get_physics_frames()
	var id := player.get_instance_id()
	# Fire Bar contact runs before the NES updates the player's sprite X for this frame.
	var previous := (
		_last_probe_x if _last_player_id == id and _last_probe_tick == tick - 1 else screen_x
	)
	_last_player_id = id
	_last_probe_tick = tick
	_last_probe_x = screen_x
	return previous


static func player_feet_y(mario: Mario) -> float:
	var feet_y := mario.body.global_position.y
	# A supported body can sit just above the surface because of the physics safe margin.
	return roundf(feet_y) if mario.has_floor_support() else feet_y


func touches_player(feet_y: float, short: bool, view: Rect2, probe_screen_x: int) -> bool:
	var player_y := floori(feet_y) - 32
	var top := floori(view.position.y)
	if player_y < top or player_y >= top + 256:
		return false
	var origin := Vector2i(global_position.floor()) + ORIGIN_OFFSET
	var left := floori(view.position.x)
	var right := floori(view.end.x) - left - 16
	for index in range(length + 1):
		var fireball := origin + segment_offset(index)
		var screen_x := fireball.x - left
		if screen_x < 0 or screen_x >= right or absi(probe_screen_x - screen_x) >= 8:
			continue
		for dy: int in [24] if short else [0, 12, 24]:
			if absi(player_y + dy - fireball.y) < 8:
				return true
	return false


func _update_segments() -> void:
	var frame := (GameHandler.animation_clock.tick_count >> 2) & 3
	for index in range(_segments.size()):
		_segments[index].position = Vector2(PIVOT + segment_offset(index))
		_segments[index].frame = frame


static func _fold_angle(angle: int) -> int:
	var folded := angle & 15
	return mini(folded, 16 - folded)

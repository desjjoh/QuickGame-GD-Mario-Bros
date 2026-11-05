class_name FlagpoleEntity
extends BaseClimbable
## Visual capability only. A level-owned presentation requests each descent step.

@onready var _flag_origin: Vector2 = $Visuals/Flag.position
var _flag_fraction: int = 0


func lower_flag(delta: float, speed: float) -> bool:
	var flag := $Visuals/Flag as Sprite2D
	# Reference flag top stops at $aa while base top is $c0 (sprite center +8).
	var target_y := climb_bottom.global_position.y - 14.0
	# The reference checks completion before moving and retains the fractional byte.
	if flag.global_position.y >= target_y:
		return true
	_flag_fraction += roundi(speed * delta * 256.0)
	var pixels := floori(float(_flag_fraction) / 256.0)
	_flag_fraction %= 256
	flag.global_position.y += pixels
	return false


func reset_flag() -> void:
	_flag_fraction = 0
	$Visuals/Flag.position = _flag_origin
	$Visuals/Flag.reset_physics_interpolation()


func attachment_fraction(player: BasePlayer, from_feet: Vector2, to_feet: Vector2) -> float:
	if not is_available() or not is_instance_valid(player) or player.is_dead or player.is_shutdown:
		return -1.0
	# HandleClimbing accepts the NES player's X low nibble $06..$09.
	# With our +8px body origin, these are two bands relative to the shaft.
	var probe := Vector2(0.0, player.climbing.capture_probe_offset_y)
	var first := INF
	for band in [Vector2(-10.0, -6.0), Vector2(6.0, 10.0)]:
		var low := Vector2(climb_top.global_position.x + band.x, _capture_top(player))
		var high := Vector2(
			climb_top.global_position.x + band.y - 0.0001, climb_bottom.global_position.y - 0.0001
		)
		var fraction := _sweep_fraction(from_feet + probe, to_feet + probe, low, high)
		if fraction >= 0.0:
			first = minf(first, fraction)
	return first if is_finite(first) else -1.0


func _capture_top(_player: BasePlayer) -> float:
	# The whole ball metatile is climbable, including its transparent top pixels.
	return $Visuals/Top.to_global(Vector2(0.0, -8.0)).y

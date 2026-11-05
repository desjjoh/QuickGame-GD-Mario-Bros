class_name BaseClimbable
extends BaseEntity
## Non-solid climbing surface. The player owns controls and motion.

signal player_attached(player: BasePlayer)
signal player_detached(player: BasePlayer)

@export var enabled: bool = true
## Half-width of the narrow shaft capture band, not a feet-distance allowance.
@export var attachment_tolerance: float = 2.0

@onready var climb_top: Marker2D = $ClimbTop
@onready var climb_bottom: Marker2D = $ClimbBottom


func _ready() -> void:
	# Set this before activity registration snapshots callback settings.
	# Detection is signal-driven; an empty surface never polls input or ticks.
	set_process(false)
	set_physics_process(false)
	super()
	$Detection.body_entered.connect(_on_body_entered)
	$Detection.body_exited.connect(_on_body_exited)


func is_available() -> bool:
	return enabled and not is_shutdown and not gameplay_suspended and not activity_suspended


func overlaps_body(player: BasePlayer) -> bool:
	var detection := $Detection/CollisionShape2D as CollisionShape2D
	var region: Rect2 = detection.global_transform * detection.shape.get_rect()
	var bounds: Rect2 = (
		player.collision_shape.global_transform * player.collision_shape.shape.get_rect()
	)
	return region.intersects(bounds)


func can_attach(player: BasePlayer) -> bool:
	return (
		attachment_fraction(player, player.body.global_position, player.body.global_position) >= 0.0
	)


func attachment_fraction(player: BasePlayer, from_feet: Vector2, to_feet: Vector2) -> float:
	if not is_available() or not is_instance_valid(player) or player.is_dead or player.is_shutdown:
		return -1.0
	# Sweep the capture envelope supplied by this surface (body or side probe).
	var bounds := _capture_bounds(player)
	var half := bounds.size / 2.0
	var offset := bounds.get_center() - player.body.global_position
	var low := (
		Vector2(climb_top.global_position.x - attachment_tolerance, _capture_top(player)) - half
	)
	var high := (
		Vector2(
			climb_top.global_position.x + attachment_tolerance, climb_bottom.global_position.y + 0.5
		)
		+ half
	)
	return _sweep_fraction(from_feet + offset, to_feet + offset, low, high)


func _sweep_fraction(from: Vector2, to: Vector2, low: Vector2, high: Vector2) -> float:
	var origin := from
	var motion := to - from
	var first := 0.0
	var last := 1.0
	for axis in range(2):
		if is_zero_approx(motion[axis]):
			if origin[axis] < low[axis] or origin[axis] > high[axis]:
				return -1.0
		else:
			var enter := (low[axis] - origin[axis]) / motion[axis]
			var leave := (high[axis] - origin[axis]) / motion[axis]
			first = maxf(first, minf(enter, leave))
			last = minf(last, maxf(enter, leave))
			if first > last:
				return -1.0
	return first


func _capture_bounds(player: BasePlayer) -> Rect2:
	return player.collision_shape.global_transform * player.collision_shape.shape.get_rect()


func _capture_top(player: BasePlayer) -> float:
	return climb_top.global_position.y - _capture_bounds(player).size.y


func notify_attached(player: BasePlayer) -> void:
	player_attached.emit(player)


func notify_detached(player: BasePlayer) -> void:
	player_detached.emit(player)


func _on_body_entered(body: Node2D) -> void:
	var player := body.get_parent() as BasePlayer
	if player != null and body == player.body:
		player.climbing.register_surface(self)


func _on_body_exited(body: Node2D) -> void:
	var player := body.get_parent() as BasePlayer
	if player != null and body == player.body:
		player.climbing.unregister_surface(self)


func attachment_y(feet_y: float) -> float:
	return clampf(feet_y, climb_top.global_position.y, climb_bottom.global_position.y)

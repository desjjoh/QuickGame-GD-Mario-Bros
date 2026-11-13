@tool
class_name FireBarSpawner
extends EntitySpawner

const PREVIEW_COLOR := Color(1.0, 0.55, 0.18, 0.75)

@export var length: FireBar.Length = FireBar.Length.SHORT:
	set(value):
		length = value
		if Engine.is_editor_hint():
			queue_redraw()
@export var speed: FireBar.Speed = FireBar.Speed.STANDARD
@export var direction: FireBar.Direction = FireBar.Direction.CLOCKWISE


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		queue_redraw()
		return
	super()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		super()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var reach := length * 8.0
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 64, PREVIEW_COLOR, 1.0, true)
	draw_line(Vector2.ZERO, Vector2.UP * reach, PREVIEW_COLOR, 1.0)
	draw_circle(Vector2.ZERO, 3.0, PREVIEW_COLOR)


func update_activity(_wake_region: Rect2, _sleep_region: Rect2, theme: AreaTheme) -> void:
	if is_shutdown or _attempted or not is_instance_valid(_area):
		return
	var spawn_region := _area.get_enemy_spawn_region()
	# The scene is placed at the pivot. The reference parser uses the tile's left edge.
	var marker_x := global_position.x - FireBar.PIVOT.x
	if marker_x < spawn_region.position.x or marker_x >= spawn_region.end.x:
		return
	_attempted = true
	var actor := _instantiate_actor()
	var bar := actor as FireBar
	if bar == null:
		if actor != null:
			actor.free()
		push_error("Fire Bar placement requires a FireBar scene.")
		return
	bar.length = length
	bar.speed = speed
	bar.direction = direction
	bar.spawner_manages_activity = true
	bar.position = -Vector2(FireBar.PIVOT)
	_attach_actor(bar, theme)

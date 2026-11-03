class_name SharedShadowComposer
extends CanvasGroup
## Render-only grouping. Gameplay nodes retain their scene ownership and transforms.

var world_root: Node2D
var screen_root: Control
var _level: BaseLevel
var _level_material: Material
var _routed_players: Node2D
var _players_behind_world: bool = false

func configure(world: Node2D, screen: Control) -> void:
	world_root = world
	screen_root = screen
	RenderingServer.canvas_item_set_parent(world_root.get_canvas_item(), get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(world_root.get_canvas_item(), 0)
	# Camera interpolation is already present in the submitted render transform.
	RenderingServer.canvas_item_set_interpolated(world_root.get_canvas_item(), false)
	RenderingServer.canvas_item_set_parent(screen_root.get_canvas_item(), get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(screen_root.get_canvas_item(), 1)
	RenderingServer.frame_pre_draw.connect(sync_rendering)
	sync_rendering()

func bind_level(level: BaseLevel) -> void:
	if GameHandler.current_level != level or level.is_shutdown:
		return
	_routed_players = null
	_level = level
	_level_material = level.material
	material = _level_material
	# The persistent group supplies the one shadow; no nested level composite.
	level.material = null
	RenderingServer.canvas_item_set_canvas_group_mode(level.get_canvas_item(), RenderingServer.CANVAS_GROUP_MODE_DISABLED)
	sync_rendering()

func _process(_delta: float) -> void:
	# Also maintain valid screen transforms in headless/manual-frame tests.
	sync_rendering()

func sync_rendering() -> void:
	if not is_instance_valid(screen_root) or not is_instance_valid(world_root):
		return
	# Game owns a screen-space canvas: HUD never cancels a moving camera.
	# Only world render transforms receive the final interpolated camera matrix.
	var camera_transform := get_viewport().canvas_transform
	RenderingServer.canvas_item_set_transform(world_root.get_canvas_item(), camera_transform * world_root.global_transform)
	screen_root.position = Vector2.ZERO
	screen_root.rotation = 0.0
	screen_root.scale = Vector2.ONE
	screen_root.size = get_viewport_rect().size
	RenderingServer.canvas_item_set_transform(screen_root.get_canvas_item(), Transform2D.IDENTITY)
	if not is_instance_valid(_level) or not is_instance_valid(_level.players):
		return
	var players := _level.players
	var behind_world := players.get_index() < _level.get_node("Areas").get_index()
	if _routed_players != players or behind_world != _players_behind_world:
		RenderingServer.canvas_item_set_interpolated(players.get_canvas_item(), false)
		_routed_players = players
		_players_behind_world = behind_world
		var render_parent := _level.get_canvas_item() if behind_world else get_canvas_item()
		RenderingServer.canvas_item_set_parent(players.get_canvas_item(), render_parent)
		RenderingServer.canvas_item_set_draw_index(players.get_canvas_item(), players.get_index() if behind_world else 2)
	var render_transform := players.transform if behind_world else camera_transform * players.global_transform
	RenderingServer.canvas_item_set_transform(players.get_canvas_item(), render_transform)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_rendering):
		RenderingServer.frame_pre_draw.disconnect(sync_rendering)

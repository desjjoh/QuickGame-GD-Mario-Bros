class_name SharedShadowComposer
extends Node2D
## Render-only grouping. Gameplay nodes retain their scene ownership and transforms.

const SHADOW_PADDING: int = 12
const HORIZONTAL_SHADER = preload("res://scenes/ui/shaders/shadow_horizontal.gdshader")
const COMPOSITE_SHADER = preload("res://scenes/ui/shaders/shadow_composite.gdshader")

var _shadow_enabled: bool = true
var _requested_enabled: bool = true
var _level_style: ShadowStyle
var shadow_style: ShadowStyle
var _source: SubViewport
var _horizontal: SubViewport
var _source_root: Node2D
var _horizontal_rect: ColorRect
var _composite: ShaderMaterial
var _render_size: Vector2i
var _parameters: Dictionary = {}
var world_root: Node2D
var screen_root: Control
var _level: BaseLevel
var _level_material: Material
var _routed_players: Node2D
var _players_behind_world: bool = false
var _routed_decorations: TileMapLayer
var _routed_background: ColorRect


func configure(world: Node2D, screen: Control) -> void:
	world_root = world
	screen_root = screen
	_create_passes()
	RenderingServer.canvas_item_set_parent(world_root.get_canvas_item(), _foreground_parent())
	RenderingServer.canvas_item_set_draw_index(world_root.get_canvas_item(), 0)
	# Camera interpolation is already present in the submitted render transform.
	RenderingServer.canvas_item_set_interpolated(world_root.get_canvas_item(), false)
	RenderingServer.canvas_item_set_parent(screen_root.get_canvas_item(), _foreground_parent())
	RenderingServer.canvas_item_set_draw_index(screen_root.get_canvas_item(), 1)
	RenderingServer.frame_pre_draw.connect(sync_rendering)
	sync_rendering()


func bind_level(level: BaseLevel) -> void:
	if level.is_shutdown:
		return
	_unbind_level()
	_level = level
	level.tree_exiting.connect(_unbind_level)
	_set_style()
	# Capture the foreground only; the level must not apply a nested CanvasGroup effect.
	level.material = null
	RenderingServer.canvas_item_set_canvas_group_mode(
		level.get_canvas_item(), RenderingServer.CANVAS_GROUP_MODE_DISABLED
	)
	sync_rendering()


func _unbind_level() -> void:
	_restore_background()
	_restore_decorations()
	_routed_background = null
	_routed_decorations = null
	if is_instance_valid(_routed_players) and is_instance_valid(_level):
		var item := _routed_players.get_canvas_item()
		RenderingServer.canvas_item_set_parent(item, _level.get_canvas_item())
		RenderingServer.canvas_item_set_transform(item, _routed_players.transform)
		RenderingServer.canvas_item_set_interpolated(
			item, _routed_players.is_physics_interpolated()
		)
	_routed_players = null
	if is_instance_valid(_level) and _level.tree_exiting.is_connected(_unbind_level):
		_level.tree_exiting.disconnect(_unbind_level)
	_level = null


func set_shadow_style(value: ShadowStyle) -> void:
	shadow_style = value
	if _source != null:
		_set_style()


func set_shadow_enabled(value: bool) -> void:
	_requested_enabled = value
	_apply_shadow_mode()


func _create_passes() -> void:
	_source = _make_viewport("ShadowForeground")
	_source_root = Node2D.new()
	_source.add_child(_source_root)
	_horizontal = _make_viewport("ShadowHorizontal")
	_horizontal_rect = ColorRect.new()
	_horizontal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var horizontal_material := ShaderMaterial.new()
	horizontal_material.shader = HORIZONTAL_SHADER
	horizontal_material.set_shader_parameter("foreground_texture", _source.get_texture())
	_horizontal_rect.material = horizontal_material
	_horizontal.add_child(_horizontal_rect)
	_composite = ShaderMaterial.new()
	_composite.shader = COMPOSITE_SHADER
	_composite.set_shader_parameter("foreground_texture", _source.get_texture())
	_composite.set_shader_parameter("horizontal_texture", _horizontal.get_texture())
	_set_style()


func _make_viewport(node_name: String) -> SubViewport:
	var buffer := SubViewport.new()
	buffer.name = node_name
	buffer.disable_3d = true
	buffer.transparent_bg = true
	buffer.world_2d = World2D.new()
	buffer.gui_disable_input = true
	buffer.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(buffer)
	return buffer


func _foreground_parent() -> RID:
	return _source_root.get_canvas_item() if _shadow_enabled else get_canvas_item()


func _apply_shadow_mode() -> void:
	if _source == null:
		return
	_shadow_enabled = _requested_enabled and _level_material != null
	material = _composite if _shadow_enabled else null
	var update_mode := SubViewport.UPDATE_ALWAYS if _shadow_enabled else SubViewport.UPDATE_DISABLED
	_source.render_target_update_mode = update_mode
	_horizontal.render_target_update_mode = (
		update_mode
		if _level_style != null and _level_style.uses_blur
		else SubViewport.UPDATE_DISABLED
	)
	for root in [world_root, screen_root]:
		if is_instance_valid(root):
			RenderingServer.canvas_item_set_parent(root.get_canvas_item(), _foreground_parent())
	_routed_players = null
	queue_redraw()


func _set_style() -> void:
	_level_style = shadow_style
	_level_material = (
		_level_style.composite_material.duplicate()
		if _level_style != null and _level_style.composite_material != null
		else null
	)
	_parameters.clear()
	if _level_material is ShaderMaterial:
		_composite.shader = _level_material.shader
		_horizontal_rect.material.shader = _level_style.horizontal_shader
	_apply_shadow_mode()


func _sync_passes() -> void:
	if shadow_style != _level_style:
		_set_style()
	var dimensions := Vector2i(get_viewport_rect().size) + Vector2i.ONE * SHADOW_PADDING * 2
	if dimensions != _render_size:
		_render_size = dimensions
		_source.size = dimensions
		_horizontal.size = dimensions
		_horizontal_rect.size = Vector2(dimensions)
		queue_redraw()
	if not _shadow_enabled or not _level_material is ShaderMaterial:
		return
	for parameter in ["blur_radius", "shadow_offset", "shadow_color", "shadow_enabled"]:
		var value: Variant = _level_material.get_shader_parameter(parameter)
		if not _parameters.has(parameter) or _parameters[parameter] != value:
			_parameters[parameter] = value
			_composite.set_shader_parameter(parameter, value)
			if parameter == "blur_radius":
				_horizontal_rect.material.set_shader_parameter(parameter, value)


func _draw() -> void:
	if _shadow_enabled and _source != null:
		draw_texture_rect(
			_source.get_texture(),
			Rect2(-Vector2.ONE * SHADOW_PADDING, Vector2(_render_size)),
			false
		)


func _process(_delta: float) -> void:
	# Also maintain valid screen transforms in headless/manual-frame tests.
	sync_rendering()


func sync_rendering() -> void:
	if not is_instance_valid(screen_root) or not is_instance_valid(world_root):
		return
	# Game owns a screen-space canvas: HUD never cancels a moving camera.
	# Only world render transforms receive the final interpolated camera matrix.
	_sync_passes()
	# Scene-tree changes can refresh engine draw indices after manual routing.
	RenderingServer.canvas_item_set_draw_index(world_root.get_canvas_item(), 0)
	RenderingServer.canvas_item_set_draw_index(screen_root.get_canvas_item(), 1)
	var camera_transform := get_viewport().canvas_transform
	_sync_background(camera_transform)
	_sync_decorations(camera_transform)
	# A transparent border retains offscreen silhouettes that cast into the visible image.
	var padding := Vector2.ONE * SHADOW_PADDING if _shadow_enabled else Vector2.ZERO
	var capture_transform := Transform2D(0.0, padding)
	RenderingServer.canvas_item_set_transform(
		world_root.get_canvas_item(),
		capture_transform * camera_transform * world_root.global_transform
	)
	screen_root.position = Vector2.ZERO
	screen_root.rotation = 0.0
	screen_root.scale = Vector2.ONE
	screen_root.size = get_viewport_rect().size
	RenderingServer.canvas_item_set_transform(screen_root.get_canvas_item(), capture_transform)
	if not is_instance_valid(_level) or not is_instance_valid(_level.players):
		return
	var players := _level.players
	var behind_world := players.get_index() < _level.get_node("Areas").get_index()
	if _routed_players != players or behind_world != _players_behind_world:
		RenderingServer.canvas_item_set_interpolated(players.get_canvas_item(), false)
		_routed_players = players
		_players_behind_world = behind_world
		var render_parent := _level.get_canvas_item() if behind_world else _foreground_parent()
		RenderingServer.canvas_item_set_parent(players.get_canvas_item(), render_parent)
	RenderingServer.canvas_item_set_draw_index(
		players.get_canvas_item(), players.get_index() if behind_world else 2
	)
	var render_transform := (
		players.transform
		if behind_world
		else capture_transform * camera_transform * players.global_transform
	)
	RenderingServer.canvas_item_set_transform(players.get_canvas_item(), render_transform)


func _sync_decorations(camera_transform: Transform2D) -> void:
	var decorations: TileMapLayer
	if is_instance_valid(_level) and is_instance_valid(_level.active_area):
		decorations = (
			_level.active_area.get_node_or_null("Layouts/DecorationLayout") as TileMapLayer
		)
	if _routed_decorations != decorations:
		_restore_decorations()
		_routed_decorations = decorations
	if not is_instance_valid(decorations):
		return
	var item := decorations.get_canvas_item()
	RenderingServer.canvas_item_set_parent(item, get_canvas_item())
	RenderingServer.canvas_item_set_draw_behind_parent(item, true)
	RenderingServer.canvas_item_set_draw_index(item, 1)
	RenderingServer.canvas_item_set_interpolated(item, false)
	RenderingServer.canvas_item_set_transform(item, camera_transform * decorations.global_transform)
	RenderingServer.canvas_item_set_visible(item, decorations.is_visible_in_tree())


func _restore_decorations() -> void:
	if not is_instance_valid(_routed_decorations):
		return
	var item := _routed_decorations.get_canvas_item()
	RenderingServer.canvas_item_set_parent(
		item, (_routed_decorations.get_parent() as CanvasItem).get_canvas_item()
	)
	RenderingServer.canvas_item_set_draw_behind_parent(item, false)
	RenderingServer.canvas_item_set_transform(item, _routed_decorations.transform)
	RenderingServer.canvas_item_set_interpolated(
		item, _routed_decorations.is_physics_interpolated()
	)


func _exit_tree() -> void:
	_unbind_level()
	if RenderingServer.frame_pre_draw.is_connected(sync_rendering):
		RenderingServer.frame_pre_draw.disconnect(sync_rendering)


func _sync_background(camera_transform: Transform2D) -> void:
	var fill: ColorRect
	if is_instance_valid(_level) and is_instance_valid(_level.active_area):
		_level.active_area.refresh_background()
		fill = _level.active_area.get_node_or_null("Background") as ColorRect
	if _routed_background != fill:
		_restore_background()
		_routed_background = fill
	if not is_instance_valid(fill):
		return
	var item := fill.get_canvas_item()
	RenderingServer.canvas_item_set_parent(item, get_canvas_item())
	RenderingServer.canvas_item_set_draw_behind_parent(item, true)
	RenderingServer.canvas_item_set_draw_index(item, 0)
	RenderingServer.canvas_item_set_interpolated(item, false)
	RenderingServer.canvas_item_set_transform(item, camera_transform * fill.get_global_transform())
	RenderingServer.canvas_item_set_visible(item, fill.is_visible_in_tree())


func _restore_background() -> void:
	if not is_instance_valid(_routed_background):
		return
	var item := _routed_background.get_canvas_item()
	RenderingServer.canvas_item_set_parent(
		item, (_routed_background.get_parent() as CanvasItem).get_canvas_item()
	)
	RenderingServer.canvas_item_set_draw_behind_parent(item, true)
	RenderingServer.canvas_item_set_transform(item, _routed_background.get_transform())
	RenderingServer.canvas_item_set_interpolated(item, _routed_background.is_physics_interpolated())

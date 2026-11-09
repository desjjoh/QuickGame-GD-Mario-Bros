@tool
extends EditorPlugin

const COIN_TEXTURE := preload("res://assets/palettes/overworld/interactibles/items/coins.tres")
const COIN_FRAME := Rect2(0, 0, 16, 16)
const PREVIEW_TINT := Color(1, 1, 1, 0.65)
const ONE_UP_SCENE := preload("res://scenes/entities/powerups/one_up_mushroom.tscn")
const ONE_UP_TEXTURE := preload("res://assets/palettes/overworld/misc/green-mushroom.png")
const SUPER_TEXTURE := preload("res://assets/items/red-mushroom.png")
const STARMAN_SCENE := preload("res://scenes/entities/powerups/starman.tscn")
const STARMAN_TEXTURE := preload("res://assets/palettes/overworld/misc/starman.png")

enum Brush { TILES, COIN, ONE_UP, TIMED_COINS, TIERED, STARMAN }

var _brush: OptionButton
var _layer: TileMapLayer


func _enter_tree() -> void:
	_brush = OptionButton.new()
	_brush.add_item("Paint Tiles", Brush.TILES)
	_brush.add_item("Apply Coin Reward", Brush.COIN)
	_brush.add_item("Apply 1-Up Reward", Brush.ONE_UP)
	_brush.add_item("Apply Timed Coins Reward", Brush.TIMED_COINS)
	_brush.add_item("Apply Tiered Power-Up Reward", Brush.TIERED)
	_brush.add_item("Apply Starman Reward", Brush.STARMAN)
	_brush.tooltip_text = "Choose a reward, then click a painted reward block."
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _brush)
	_brush.hide()
	set_force_draw_over_forwarding_enabled()
	update_overlays()


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _brush)
	_brush.queue_free()


func _handles(object: Object) -> bool:
	return object is TileMapLayer and object.name == &"EntityLayout"


func _edit(object: Object) -> void:
	_layer = object as TileMapLayer


func _make_visible(visible: bool) -> void:
	_brush.visible = visible
	if not visible:
		_brush.select(Brush.TILES)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _brush.visible or _brush.get_selected_id() == Brush.TILES:
		return false
	if not is_instance_valid(_layer):
		return false
	if event is InputEventMouseMotion:
		return (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.pressed:
		var local: Vector2 = _layer_to_viewport(_layer).affine_inverse() * event.position
		_apply_reward(_layer.local_to_map(local))
	return true


func _apply_reward(cell: Vector2i) -> void:
	var area := _layer.get_parent().get_parent() as BaseLevelArea
	if area == null or not _is_reward_block(_layer, cell):
		return
	var reward := _reward_for_brush(_brush.get_selected_id())
	var previous := area.question_block_rewards
	var old := BlockReward.resolve(previous.get(cell))
	var selected := BlockReward.resolve(reward)
	if old.kind == selected.kind and old.power_up_scene == selected.power_up_scene:
		return
	var updated := previous.duplicate()
	if reward == null:
		updated.erase(cell)
	else:
		updated[cell] = reward
	_commit_reward_edit(area, previous, updated)


func _reward_for_brush(brush: int) -> BlockReward:
	if brush == Brush.COIN:
		return null
	var reward := BlockReward.new()
	match brush:
		Brush.TIMED_COINS:
			reward.kind = BlockReward.Kind.TIMED_COINS
		Brush.TIERED:
			reward.kind = BlockReward.Kind.TIERED_POWER_UP
		Brush.ONE_UP:
			reward.kind = BlockReward.Kind.POWER_UP
			reward.power_up_scene = ONE_UP_SCENE
		Brush.STARMAN:
			reward.kind = BlockReward.Kind.POWER_UP
			reward.power_up_scene = STARMAN_SCENE
	return reward


func _commit_reward_edit(
	area: BaseLevelArea,
	previous: Dictionary[Vector2i, Resource],
	updated: Dictionary[Vector2i, Resource]
) -> void:
	var history := get_undo_redo()
	history.create_action("Paint Block Reward", UndoRedo.MERGE_DISABLE, area)
	history.add_do_property(area, &"question_block_rewards", updated)
	history.add_undo_property(area, &"question_block_rewards", previous)
	history.add_do_method(self, &"update_overlays")
	history.add_undo_method(self, &"update_overlays")
	history.commit_action()


func _layer_to_viewport(layer: TileMapLayer) -> Transform2D:
	var editor_canvas := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	return editor_canvas * layer.get_global_transform_with_canvas()


func _is_reward_block(layer: TileMapLayer, cell: Vector2i) -> bool:
	if layer.tile_set == null or layer.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
		return false
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return false
	var id := String(data.get_custom_data("entity_id"))
	return (
		id in ["question_block", "hidden_question_block", "reward_brick", "reward_brick_alternate"]
	)


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		return

	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for node in scene.find_children("EntityLayout", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if not layer.is_visible_in_tree() or layer.tile_set == null:
			continue
		if layer.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
			continue
		overlay.draw_set_transform_matrix(_layer_to_viewport(layer))
		var area := layer.get_parent().get_parent() as BaseLevelArea
		var theme := area.theme if area != null else null
		for cell in layer.get_used_cells():
			if not _is_reward_block(layer, cell):
				continue
			var destination := Rect2(
				layer.map_to_local(cell) - COIN_FRAME.size * 0.5, COIN_FRAME.size
			)
			var reward := BlockReward.resolve(
				area.question_block_rewards.get(cell) if area != null else null
			)
			_draw_reward_preview(overlay, destination, reward, theme)
	overlay.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_reward_preview(
	overlay: Control, destination: Rect2, reward: BlockReward, theme: AreaTheme
) -> void:
	if reward.kind == BlockReward.Kind.TIMED_COINS:
		# A stack means multiple coins, not a fixed coin count.
		for offset in [Vector2(-3, -3), Vector2.ZERO, Vector2(3, 3)]:
			overlay.draw_texture_rect_region(
				COIN_TEXTURE,
				Rect2(destination.position + Vector2(2, 2) + offset, Vector2(12, 12)),
				COIN_FRAME,
				PREVIEW_TINT
			)
	elif (
		reward.kind == BlockReward.Kind.TIERED_POWER_UP
		or (reward.kind == BlockReward.Kind.POWER_UP and reward.power_up_scene == ONE_UP_SCENE)
	):
		var base_texture := (
			SUPER_TEXTURE if reward.kind == BlockReward.Kind.TIERED_POWER_UP else ONE_UP_TEXTURE
		)
		var texture := theme.resolve_texture(base_texture) if theme != null else base_texture
		overlay.draw_texture_rect(texture, destination, false, PREVIEW_TINT)
	elif reward.kind == BlockReward.Kind.POWER_UP and reward.power_up_scene == STARMAN_SCENE:
		var texture := theme.resolve_texture(STARMAN_TEXTURE) if theme != null else STARMAN_TEXTURE
		overlay.draw_texture_rect_region(texture, destination, Rect2(16, 0, 16, 16), PREVIEW_TINT)
	else:
		overlay.draw_texture_rect_region(COIN_TEXTURE, destination, COIN_FRAME, PREVIEW_TINT)

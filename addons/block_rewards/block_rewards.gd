@tool
extends EditorPlugin

const COIN_TEXTURE := preload("res://assets/palettes/overworld/interactibles/items/coins.tres")
const COIN_FRAME := Rect2(0, 0, 16, 16)
const COIN_TINT := Color(1, 1, 1, 0.65)
const ONE_UP_SCENE := "res://scenes/entities/powerups/one_up_mushroom.tscn"
const ONE_UP_TEXTURE := preload("res://assets/palettes/overworld/misc/green-mushroom.png")


func _enter_tree() -> void:
	set_force_draw_over_forwarding_enabled()
	update_overlays()


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		return

	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var editor_canvas := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	for node in scene.find_children("EntityLayout", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if not layer.is_visible_in_tree() or layer.tile_set == null:
			continue
		if layer.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
			continue
		overlay.draw_set_transform_matrix(editor_canvas * layer.get_global_transform_with_canvas())
		var area := layer.get_parent().get_parent() as BaseLevelArea
		for cell in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data != null and data.get_custom_data("entity_id") == "question_block":
				var destination := Rect2(layer.map_to_local(cell) - COIN_FRAME.size * 0.5, COIN_FRAME.size)
				var reward: PackedScene = area.question_block_rewards.get(cell) if area != null else null
				if reward != null and reward.resource_path == ONE_UP_SCENE:
					var texture := area.theme.resolve_texture(ONE_UP_TEXTURE) if area.theme else ONE_UP_TEXTURE
					overlay.draw_texture_rect(texture, destination, false, COIN_TINT)
				else:
					overlay.draw_texture_rect_region(COIN_TEXTURE, destination, COIN_FRAME, COIN_TINT)
	overlay.draw_set_transform_matrix(Transform2D.IDENTITY)

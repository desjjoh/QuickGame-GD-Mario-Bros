extends RefCounted


static func hits_terrain(item: CanvasItem, query: PhysicsPointQueryParameters2D) -> bool:
	# TileMap terrain uses the default canvas. Entity bodies can use the item's CanvasLayer.
	var space := item.get_world_2d().direct_space_state
	query.canvas_instance_id = 0
	if not space.intersect_point(query, 1).is_empty():
		return true
	var canvas := item.get_canvas_layer_node()
	if canvas == null:
		return false
	query.canvas_instance_id = canvas.get_instance_id()
	return not space.intersect_point(query, 1).is_empty()

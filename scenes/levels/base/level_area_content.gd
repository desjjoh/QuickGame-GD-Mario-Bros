class_name LevelAreaContent
extends Node
## Materializes painted entities and captures snapshots; BaseLevel owns lifecycle and storage.

@onready var level: BaseLevel = $"../.."


func populate(area: BaseLevelArea, saved_entities: Dictionary) -> void:
	area.entity_persistence.clear()
	populate_layout(area, area.get_node("Layouts/EntityLayout"), saved_entities)
	populate_layout(area, area.get_node("Layouts/EnemyLayout"), {})


func find_layout_entity(area: BaseLevelArea, entity_id: StringName, cell: Vector2i) -> BaseEntity:
	var objects := area.get_node("WorldObjects")
	return objects.get_node_or_null(NodePath(_entity_name(entity_id, cell))) as BaseEntity


func populate_layout(area: BaseLevelArea, layout: TileMapLayer, saved_entities: Dictionary) -> void:
	var objects := area.get_node("WorldObjects") as Node2D
	# Markers remain editable in the scene, but only entities render at runtime.
	layout.hide()
	if layout.tile_set == null:
		return
	if layout.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
		push_error("EntityLayout TileSet needs an entity_id custom-data layer.")
		return
	for cell: Vector2i in layout.get_used_cells():
		var data := layout.get_cell_tile_data(cell)
		if data == null:
			continue
		var entity_id := StringName(str(data.get_custom_data("entity_id")))
		var scene: PackedScene = level.entity_scenes.get(entity_id)
		if scene == null:
			push_error("EntityLayout cell %s has unmapped entity_id '%s'." % [cell, entity_id])
			continue
		var entity_name := _entity_name(entity_id, cell)
		var progress: Dictionary = saved_entities.get(entity_name, {})
		var instance := scene.instantiate()
		if not instance is BaseEntity:
			push_error("EntityLayout scenes must inherit BaseEntity: %s" % entity_id)
			instance.free()
			continue
		area.entity_persistence[entity_name] = instance.persist_progress
		if not instance.persist_progress:
			progress = {}
		elif progress.get("removed", false):
			instance.free()
			continue
		if instance is TransportEntity and not area.configure_transport(instance, cell):
			instance.free()
			continue
		instance.visual_theme = area.theme
		if instance is QuestionBlock:
			instance.configure_reward(area.question_block_rewards.get(cell))
		if instance is PipeEntrance:
			instance.attach_pipe_spawn(area.pipe_spawns.get(cell) as PipeSpawn)
		instance.name = entity_name
		instance.restore_area_state(progress.get("state", {}))
		# Block/entity marker origins are the top-left of each grid cell.
		var local_origin := layout.map_to_local(cell) - Vector2(layout.tile_set.tile_size) / 2.0
		instance.position = objects.to_local(layout.to_global(local_origin))
		objects.add_child(instance)
		if level.ending_presentation != null:
			level.ending_presentation.bind_entity(instance, cell, area)


func capture(area: BaseLevelArea) -> Dictionary:
	var layouts: Dictionary = {}
	for layer in area.get_node("Layouts").get_children():
		if layer is TileMapLayer:
			layouts[str(layer.name)] = layer.tile_map_data.duplicate()
	var entities: Dictionary = {}
	var markers := area.get_node("Layouts/EntityLayout") as TileMapLayer
	var objects := area.get_node("WorldObjects") as Node2D
	for cell: Vector2i in markers.get_used_cells():
		var data := markers.get_cell_tile_data(cell)
		if data == null:
			continue
		var id := StringName(str(data.get_custom_data("entity_id")))
		var entity_name := _entity_name(id, cell)
		var entity := objects.get_node_or_null(NodePath(entity_name)) as BaseEntity
		if entity != null:
			if not entity.persist_progress:
				continue
		elif not area.entity_persistence.get(entity_name, false):
			continue
		entities[entity_name] = {
			"removed": entity == null,
			"state": entity.capture_area_state() if entity != null else {}
		}
	return {"layouts": layouts, "entities": entities}


func _entity_name(entity_id: StringName, cell: Vector2i) -> String:
	return "%s_%s_%s" % [entity_id, cell.x, cell.y]

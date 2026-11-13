class_name LevelAreaContent
extends Node
## Materializes painted entities and captures snapshots; BaseLevel owns lifecycle and storage.

const CASTLE_PART := &"castle_part"

@onready var level: BaseLevel = $"../.."


func populate(area: BaseLevelArea, saved_entities: Dictionary, enemy_cutoff_x := -INF) -> void:
	area.entity_persistence.clear()
	populate_layout(area, area.get_node("Layouts/EntityLayout"), saved_entities)
	populate_layout(area, area.get_node("Layouts/EnemyLayout"), {}, enemy_cutoff_x)


func find_layout_entity(area: BaseLevelArea, entity_id: StringName, cell: Vector2i) -> BaseEntity:
	var objects := area.get_node("WorldObjects")
	return objects.get_node_or_null(NodePath(_entity_name(entity_id, cell))) as BaseEntity


func populate_layout(
	area: BaseLevelArea, layout: TileMapLayer, saved_entities: Dictionary, enemy_cutoff_x := -INF
) -> void:
	var objects := area.get_node("WorldObjects") as Node2D
	# Hide authoring stamps. Copy scenery cells into the runtime world.
	layout.hide()
	if layout.tile_set == null:
		return
	if layout.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
		push_error("EntityLayout TileSet needs an entity_id custom-data layer.")
		return
	var scenery: TileMapLayer = null
	for cell: Vector2i in layout.get_used_cells():
		var data := layout.get_cell_tile_data(cell)
		if data == null:
			continue
		var entity_id := StringName(str(data.get_custom_data("entity_id")))
		if entity_id == CASTLE_PART:
			if scenery == null:
				scenery = _create_castle_scenery(layout, objects)
			_copy_scenery_cell(layout, scenery, cell)
			continue
		var entity_name := _entity_name(entity_id, cell)
		var progress: Dictionary = saved_entities.get(entity_name, {})
		var entity := _create_entity(entity_id, cell)
		if entity == null:
			continue
		area.entity_persistence[entity_name] = entity.persist_progress
		if not entity.persist_progress:
			progress = {}
		elif progress.get("removed", false):
			entity.free()
			continue
		if not _configure_placement(entity, area, cell):
			entity.free()
			continue
		entity.name = entity_name
		entity.restore_area_state(progress.get("state", {}))
		# Block/entity marker origins are the top-left of each grid cell.
		var local_origin := layout.map_to_local(cell) - Vector2(layout.tile_set.tile_size) / 2.0
		entity.position = objects.to_local(layout.to_global(local_origin))
		objects.add_child(entity)
		if enemy_cutoff_x != -INF and entity is EntitySpawner:
			entity.skip_spawn_before(enemy_cutoff_x)
		if level.ending_presentation != null:
			level.ending_presentation.bind_entity(entity, cell, area)


func _create_castle_scenery(layout: TileMapLayer, objects: Node2D) -> TileMapLayer:
	var scenery := TileMapLayer.new()
	scenery.name = &"CastleParts"
	scenery.tile_set = layout.tile_set
	scenery.texture_filter = layout.texture_filter
	scenery.collision_enabled = false
	scenery.navigation_enabled = false
	objects.add_child(scenery)
	objects.move_child(scenery, 0)
	scenery.global_transform = layout.global_transform
	return scenery


func _copy_scenery_cell(layout: TileMapLayer, scenery: TileMapLayer, cell: Vector2i) -> void:
	scenery.set_cell(
		cell,
		layout.get_cell_source_id(cell),
		layout.get_cell_atlas_coords(cell),
		layout.get_cell_alternative_tile(cell)
	)


func _create_entity(entity_id: StringName, cell: Vector2i) -> BaseEntity:
	var scene: PackedScene = level.entity_scenes.get(entity_id)
	if scene == null:
		push_error("EntityLayout cell %s has unmapped entity_id '%s'." % [cell, entity_id])
		return null
	var instance := scene.instantiate()
	if not instance is BaseEntity:
		push_error("EntityLayout scenes must inherit BaseEntity: %s" % entity_id)
		instance.free()
		return null
	return instance


func _configure_placement(entity: BaseEntity, area: BaseLevelArea, cell: Vector2i) -> bool:
	if entity is TransportEntity and not area.configure_transport(entity, cell):
		return false
	entity.visual_theme = area.theme
	if entity is QuestionBlock:
		entity.configure_reward(area.question_block_rewards.get(cell))
	if entity is PipeEntrance:
		entity.attach_pipe_spawn(area.pipe_spawns.get(cell) as PipeSpawn)
	return true


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
		if id == CASTLE_PART:
			continue
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

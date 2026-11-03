extends Node


func _ready() -> void:
	var packed := load("res://scenes/levels/test_level.tscn") as PackedScene
	var expected_layouts: Dictionary = {}
	for cycle in range(3):
		var level := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as BaseLevel
		if cycle == 0:
			assert(level.get_node("Areas/MainArea/Endpoints").get_child_count() == 0,
				"The playable level must not include test endpoint examples.")
			preload("res://tests/fixtures/named_endpoints.gd").add_to(level)
		var main := level.get_node("Areas/MainArea") as BaseLevelArea
		for id in [&"near_start",&"near_end"]:
			var endpoint := main.resolve_endpoint(id)
			assert(endpoint != null and endpoint.get_parent() == main.get_node("Endpoints"))
		for child in level.get_children():
			assert(not "Endpoints#" in str(child.name), "Editor-orphaned endpoints must not be saved under the level root.")
		for area in level.get_node("Areas").get_children():
			for layer: TileMapLayer in area.get_node("Layouts").get_children():
				var key := "%s/%s" % [area.name,layer.name]
				if cycle == 0:
					expected_layouts[key] = layer.tile_map_data.duplicate()
				else:
					assert(layer.tile_map_data == expected_layouts[key], "Edit-state saving must preserve painted layout data.")
		var saved := PackedScene.new()
		assert(saved.pack(level) == OK)
		var path := "res://.godot/validation/scene-hierarchy-%s.tscn" % cycle
		assert(ResourceSaver.save(saved,path) == OK)
		level.free()
		packed = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	print("PASS: native editor-state save/reload preserves nested endpoint parents and all painted area layers across three cycles.")
	get_tree().quit()

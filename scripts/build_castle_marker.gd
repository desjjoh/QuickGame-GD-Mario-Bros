extends SceneTree
## Build themed castle paint stamps from the placed castle's sprite layout.


func _initialize() -> void:
	var scene := FileAccess.get_file_as_string("res://scenes/entities/castle/castle.tscn")
	var pattern := RegEx.new()
	(
		pattern
		. compile(
			"position = Vector2\\((\\d+), (\\d+)\\)(?:(?!\\[node)[\\s\\S])*?region_rect = Rect2\\((\\d+), (\\d+), 16, 16\\)"
		)
	)
	var tiles := pattern.search_all(scene)
	assert(not tiles.is_empty())
	for theme: String in ["underground", "castle"]:
		var folder := "res://assets/palettes/" + theme + "/tileset/"
		var atlas := load(folder + "Palette 1 (Ground and Stone).png") as Texture2D
		var art := atlas.get_image()
		art.convert(Image.FORMAT_RGBA8)
		var preview := Image.create(80, 80, false, Image.FORMAT_RGBA8)
		for tile in tiles:
			var position := Vector2i(tile.get_string(1).to_int(), tile.get_string(2).to_int())
			var origin := Vector2i(tile.get_string(3).to_int(), tile.get_string(4).to_int())
			preview.blit_rect(art, Rect2i(origin, Vector2i(16, 16)), position)
		assert(preview.save_png("res://assets/tileset/" + theme + "/previews/castle.png") == OK)
	quit()

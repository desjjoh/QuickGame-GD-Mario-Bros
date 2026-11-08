extends RefCounted
## Shared offline preview rendering; scenes never enter the live tree.


static func texture_image(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		return texture_image(texture.atlas).get_region(Rect2i(texture.region))
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


static func render_tiles(layer: TileMapLayer, theme: AreaTheme, size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for cell in layer.get_used_cells():
		assert(
			layer.get_cell_alternative_tile(cell) == 0,
			"Preview builder requires untransformed cells."
		)
		var source := (
			layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
		)
		assert(source != null)
		var texture := theme.resolve_texture(source.texture)
		var region := source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
		var at := (
			layer.position + layer.map_to_local(cell) - Vector2(layer.tile_set.tile_size) / 2.0
		)
		image.blend_rect(texture_image(texture), region, Vector2i(at))
	return image


static func save_preview(image: Image, path: String, check_only: bool) -> bool:
	if check_only:
		var existing := Image.new()
		if existing.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			push_error("Missing or invalid preview: " + path)
			return false
		existing.convert(Image.FORMAT_RGBA8)
		var differences := 0
		if existing.get_size() != image.get_size():
			push_error("Preview dimensions differ: " + path)
			return false
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var expected := image.get_pixel(x, y)
				var actual := existing.get_pixel(x, y)
				if expected.a == 0.0 and actual.a == 0.0:
					continue
				if expected != actual:
					differences += 1
		if differences > 0:
			push_error("Preview differs (%d pixels): %s" % [differences, path])
			return false
		return true
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if image.save_png(path) != OK:
		push_error("Cannot save preview: " + path)
		return false
	return true

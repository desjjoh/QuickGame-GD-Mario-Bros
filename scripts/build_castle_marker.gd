extends SceneTree
## Rebuild all themed castle stamps from the authored TileMapLayer.
const PREVIEW := preload("res://scripts/marker_preview.gd")


func _initialize() -> void:
	if not _build("castle", PREVIEW.THEME_NAMES):
		quit(1)
		return
	if not _build("large_castle", ["overworld"]):
		quit(1)
		return
	print("Castle marker previews: PASS")
	quit()


func _build(marker: String, themes: Array) -> bool:
	var castle: Node = load("res://scenes/entities/castle/" + marker + ".tscn").instantiate()
	var tiles := castle.get_node("Presentation/Tiles") as TileMapLayer
	var bounds := tiles.get_used_rect()
	var tile_size := tiles.tile_set.tile_size
	tiles.position -= Vector2(bounds.position * tile_size)
	var size := bounds.size * tile_size
	for theme_name: String in themes:
		var theme := load("res://assets/themes/" + theme_name + ".tres") as AreaTheme
		var image := PREVIEW.render_tiles(tiles, theme, size)
		if not PREVIEW.save_preview(
			image,
			PREVIEW.output_path(theme_name, marker),
			"--check" in OS.get_cmdline_user_args()
		):
			castle.free()
			return false
	castle.free()
	return true

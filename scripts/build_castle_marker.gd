extends SceneTree
## Rebuild all themed castle stamps from the authored TileMapLayer.
const PREVIEW := preload("res://scripts/marker_preview.gd")


func _initialize() -> void:
	var castle: Node = load("res://scenes/entities/castle/castle.tscn").instantiate()
	var tiles := castle.get_node("Presentation/Tiles") as TileMapLayer
	for theme_name: String in PREVIEW.THEME_NAMES:
		var theme := load("res://assets/themes/" + theme_name + ".tres") as AreaTheme
		var image := PREVIEW.render_tiles(tiles, theme, Vector2i(80, 80))
		if not PREVIEW.save_preview(
			image,
			PREVIEW.output_path(theme_name, "castle"),
			"--check" in OS.get_cmdline_user_args()
		):
			castle.free()
			quit(1)
			return
	castle.free()
	print("Castle marker previews: PASS")
	quit()

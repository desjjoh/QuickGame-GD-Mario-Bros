extends SceneTree
## Rebuild all flagpole stamps from the authored tiles and flag sprite.
const PREVIEW := preload("res://scripts/marker_preview.gd")


func _initialize() -> void:
	var flagpole: Node = (
		load("res://scenes/entities/climbables/flagpole/flagpole.tscn").instantiate()
	)
	var tiles := flagpole.get_node("Presentation/Tiles") as TileMapLayer
	var flag := flagpole.get_node("Presentation/Flag") as Sprite2D
	for theme_name: String in PREVIEW.THEME_NAMES:
		var theme := load("res://assets/themes/" + theme_name + ".tres") as AreaTheme
		var image := PREVIEW.render_tiles(tiles, theme, Vector2i(32, 176))
		var flag_image := PREVIEW.texture_image(theme.resolve_texture(flag.texture))
		var at := flag.position + flag.offset
		if flag.centered:
			at -= Vector2(flag_image.get_size()) / 2.0
		image.blend_rect(flag_image, Rect2i(Vector2i.ZERO, flag_image.get_size()), Vector2i(at))
		if not PREVIEW.save_preview(
			image,
			PREVIEW.output_path(theme_name, "flagpole"),
			"--check" in OS.get_cmdline_user_args()
		):
			flagpole.free()
			quit(1)
			return
	flagpole.free()
	print("Flagpole marker previews: PASS")
	quit()

extends SceneTree

const PREVIEW := preload("res://scripts/marker_preview.gd")


## Pack exact source pixels into the two paintable 2x2 marker previews.
func _initialize() -> void:
	var previews := {
		"pipe_entrance": ["pipe-top-1", "pipe-top-2", "pipe-1", "pipe-2"],
		"sideways_pipe_entrance": ["pipe-top-h-1", "pipe-h-1", "pipe-top-h-2", "pipe-h-2"]
	}
	for theme: String in ["overworld", "underground", "castle"]:
		var folder := "res://assets/palettes/" + theme + "/interactibles/pipes/"
		var output := (
			"res://assets/tileset/" + (theme + "/" if theme != "overworld" else "") + "previews/"
		)
		for preview: String in previews:
			var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for index in range(4):
				var part := PREVIEW.texture_image(
					load(folder + previews[preview][index] + ".tres") as Texture2D
				)
				part.convert(Image.FORMAT_RGBA8)
				image.blit_rect(
					part, Rect2i(0, 0, 16, 16), Vector2i((index % 2) * 16, (index >> 1) * 16)
				)
			if not PREVIEW.save_preview(
				image, output + preview + ".png", "--check" in OS.get_cmdline_user_args()
			):
				quit(1)
				return
	print("Pipe marker previews: PASS")
	quit()

extends SceneTree
## Rebuild the single 2x11 paint marker from the same source pixels as the scene.


func _initialize() -> void:
	for theme in ["overworld", "underground", "castle"]:
		build_marker(theme)
	quit()


func build_marker(theme: String) -> void:
	var image := Image.create(32, 176, false, Image.FORMAT_RGBA8)
	var folder := "res://assets/palettes/" + theme + "/misc/"
	var top := (load(folder + "flagpole-top.tres") as Texture2D).get_image()
	var pole := (load(folder + "flagpole-pole.tres") as Texture2D).get_image()
	var flag := (load(folder + "flagpole-flag.png") as Texture2D).get_image()
	var base := (load("res://assets/palettes/" + theme + "/tileset/block.tres") as Texture2D).get_image()
	image.blend_rect(top, Rect2i(0, 0, 16, 16), Vector2i(16, 0))
	for row in range(1, 10):
		image.blend_rect(pole, Rect2i(0, 0, 16, 16), Vector2i(16, row * 16))
	image.blend_rect(flag, Rect2i(0, 0, 16, 16), Vector2i(8, 16))
	image.blend_rect(base, Rect2i(0, 0, 16, 16), Vector2i(16, 160))
	var folder_prefix := theme + "/" if theme != "overworld" else ""
	var output := "res://assets/tileset/" + folder_prefix + "previews/"
	DirAccess.make_dir_recursive_absolute(output)
	assert(image.save_png(output + "flagpole.png") == OK)

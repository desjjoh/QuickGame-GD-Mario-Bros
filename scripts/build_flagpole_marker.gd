extends SceneTree
## Rebuild the single 2x11 paint marker from the same source pixels as the scene.


func _initialize() -> void:
	var image := Image.create(32, 176, false, Image.FORMAT_RGBA8)
	var folder := "res://assets/palettes/overworld/interactibles/flag/"
	var top := (load(folder + "flagpole-top.png") as Texture2D).get_image()
	var pole := (load(folder + "flagpole-pole.png") as Texture2D).get_image()
	var flag := (load(folder + "flagpole-flag.png") as Texture2D).get_image()
	var base := (load("res://assets/palettes/overworld/tileset/block.png") as Texture2D).get_image()
	image.blend_rect(top, Rect2i(0, 0, 16, 16), Vector2i(16, 0))
	for row in range(1, 10):
		image.blend_rect(pole, Rect2i(0, 0, 16, 16), Vector2i(16, row * 16))
	image.blend_rect(flag, Rect2i(0, 0, 16, 16), Vector2i(8, 16))
	image.blend_rect(base, Rect2i(0, 0, 16, 16), Vector2i(16, 160))
	assert(image.save_png("res://assets/tileset/previews/flagpole.png") == OK)
	quit()

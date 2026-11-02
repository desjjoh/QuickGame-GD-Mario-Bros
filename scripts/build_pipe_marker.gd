extends SceneTree
func _initialize() -> void:
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	var folder := "res://assets/Overworld (Palette 1)/interactibles/pipes/"
	var files := ["pipe-top-1.png","pipe-top-2.png","pipe-1.png","pipe-2.png"]
	for index in range(4):
		var part := (load(folder + files[index]) as Texture2D).get_image()
		part.convert(Image.FORMAT_RGBA8)
		image.blit_rect(part,Rect2i(0,0,16,16),Vector2i((index%2)*16,(index >> 1)*16))
	DirAccess.make_dir_recursive_absolute("res://assets/tileset/previews")
	assert(image.save_png("res://assets/tileset/previews/pipe_entrance.png") == OK)
	quit()

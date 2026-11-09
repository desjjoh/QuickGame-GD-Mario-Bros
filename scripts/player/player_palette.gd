class_name PlayerPalette
extends Resource
## Prebaked sprite sheets keyed by pose filename.

# Color roles in each character's original art: clothes, skin, and hair.
const MARIO_ROLES := {0xb53120: 0, 0xe69c21: 1, 0x6b6d00: 2, 0x8a8a00: 2}
const LUIGI_ROLES := {0xffffff: 0, 0xe69c21: 1, 0x109400: 2}
const FIRE_ROLES := {0xf7d8a5: 0, 0xe69c21: 1, 0xea9e22: 1, 0xb53120: 2}

@export var sheets: Dictionary[StringName, Texture2D] = {}
@export var starman_colors: Array[Color] = []

var _starman_sheets: Dictionary[Texture2D, Texture2D] = {}
var _starman_frames: Dictionary[Texture2D, Texture2D] = {}


func remap(texture: Texture2D) -> Texture2D:
	var frame := texture as AtlasTexture
	var source := frame.atlas if frame != null else texture
	if source == null:
		return texture
	var replacement: Texture2D = sheets.get(StringName(source.resource_path.get_file()))
	if replacement == null:
		return texture
	if frame == null:
		return replacement
	var result := frame.duplicate() as AtlasTexture
	result.atlas = replacement
	return result


## Recolor the live pose, preserving its dimensions, pose details, and transparency.
func remap_starman(texture: Texture2D) -> Texture2D:
	if texture == null or starman_colors.size() != 3:
		return texture
	if _starman_frames.has(texture):
		return _starman_frames[texture]
	var frame := texture as AtlasTexture
	var source := frame.atlas if frame != null else texture
	if source == null:
		return texture
	if not _starman_sheets.has(source):
		_starman_sheets[source] = _recolor_sheet(source)
	var replacement := _starman_sheets[source]
	if frame == null:
		return replacement
	var result := frame.duplicate() as AtlasTexture
	result.atlas = replacement
	_starman_frames[texture] = result
	return result


func _recolor_sheet(source: Texture2D) -> Texture2D:
	var folder := source.resource_path.get_base_dir().get_file()
	var roles := MARIO_ROLES
	if folder.begins_with("luigi"):
		roles = LUIGI_ROLES
	elif folder.ends_with("(fire)"):
		roles = FIRE_ROLES
	var image := source.get_image()
	if image == null:
		return source
	image.convert(Image.FORMAT_RGBA8)
	image.clear_mipmaps()
	var pixels := image.get_data()
	for index in range(0, pixels.size(), 4):
		if pixels[index + 3] == 0:
			continue
		var rgb := (pixels[index] << 16) | (pixels[index + 1] << 8) | pixels[index + 2]
		var role: int = roles.get(rgb, -1)
		if role >= 0:
			var rgba := starman_colors[role].to_rgba32()
			pixels[index] = rgba >> 24
			pixels[index + 1] = (rgba >> 16) & 0xff
			pixels[index + 2] = (rgba >> 8) & 0xff
	var recolored := Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels
	)
	return ImageTexture.create_from_image(recolored)

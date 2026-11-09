class_name PlayerPalette
extends Resource
## Prebaked sprite sheets keyed by pose filename.

@export var sheets: Dictionary[StringName, Texture2D] = {}


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

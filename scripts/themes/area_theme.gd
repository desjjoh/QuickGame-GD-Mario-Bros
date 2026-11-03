@tool
class_name AreaTheme
extends Resource
## Compatible TileSets and texture overrides; missing artwork stays unchanged.

@export var display_name: String
@export var terrain: TileSet
@export var decorations: TileSet
@export var entity_markers: TileSet
@export var texture_overrides: Dictionary[String, Texture2D] = {}


func resolve_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	return texture_overrides.get(texture.resource_path, texture)

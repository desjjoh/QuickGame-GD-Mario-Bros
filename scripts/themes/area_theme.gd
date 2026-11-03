@tool
class_name AreaTheme
extends Resource
## Compatible visual assets and optional soundtrack for an area theme.

@export var display_name: String
@export var terrain: TileSet
@export var decorations: TileSet
@export var entity_markers: TileSet
@export var music: AudioStream
@export var music_loop: bool = true
@export_range(-80.0, 6.0, 0.5) var music_volume_db: float = 0.0
@export var texture_overrides: Dictionary[String, Texture2D] = {}


func resolve_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	return texture_overrides.get(texture.resource_path, texture)

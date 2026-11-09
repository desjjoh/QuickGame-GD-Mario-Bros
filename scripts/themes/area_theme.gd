@tool
class_name AreaTheme
extends Resource
## Compatible visual assets for an area theme.

@export var display_name: String
## Optional copyright/accent font; title falls back to the Overworld alternate atlas.
@export var title_accent_font: Font
@export var terrain: TileSet
@export var decorations: TileSet
@export var entity_markers: TileSet
@export var enemy_markers: TileSet
@export var texture_overrides: Dictionary[String, Texture2D] = {}
## Replacement artwork for Fire transformation slots 1 through 3.
@export var fire_transform_palettes: Array[PlayerPalette] = []


func resolve_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	return texture_overrides.get(texture.resource_path, texture)

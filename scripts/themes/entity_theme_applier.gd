class_name EntityThemeApplier
extends RefCounted
## Stateless entity artwork application; resource copies remain local to each actor.


static func apply(entity: BaseEntity) -> void:
	if entity.visual_theme == null:
		return
	for child in entity.find_children("*", "Sprite2D", true, false):
		var child_sprite := child as Sprite2D
		child_sprite.texture = entity.resolve_texture(child_sprite.texture)
	for child in entity.find_children("*", "TileMapLayer", true, false):
		var layer := child as TileMapLayer
		if layer.tile_set == null:
			continue
		# Each actor owns its themed sources; other areas keep their original art.
		layer.tile_set = layer.tile_set.duplicate() as TileSet
		var source_ids: Array[int] = []
		for index in range(layer.tile_set.get_source_count()):
			source_ids.append(layer.tile_set.get_source_id(index))
		for source_id in source_ids:
			var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if source == null:
				continue
			var themed_source := source.duplicate() as TileSetAtlasSource
			themed_source.texture = entity.resolve_texture(source.texture)
			layer.tile_set.remove_source(source_id)
			layer.tile_set.add_source(themed_source, source_id)
	if entity.animation_player == null or entity.visual_theme.texture_overrides.is_empty():
		return
	# Clone animation containers only; never alter another area's shared assets.
	for library_name in entity.animation_player.get_animation_library_list():
		var original := entity.animation_player.get_animation_library(library_name)
		var library := AnimationLibrary.new()
		for animation_name in original.get_animation_list():
			var animation := original.get_animation(animation_name).duplicate() as Animation
			for track in range(animation.get_track_count()):
				if animation.track_get_type(track) != Animation.TYPE_VALUE:
					continue
				for key in range(animation.track_get_key_count(track)):
					var value = animation.track_get_key_value(track, key)
					if value is Texture2D:
						animation.track_set_key_value(track, key, entity.resolve_texture(value))
			library.add_animation(animation_name, animation)
		entity.animation_player.remove_animation_library(library_name)
		entity.animation_player.add_animation_library(library_name, library)

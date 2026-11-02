extends RefCounted
## Keep horizontal/animation tests on a flat surface now that gravity exists.


static func extend_floor(game: Node) -> void:
	var level: Node = game.get_node("LevelContainer").get_child(0)
	# These motion trials intentionally travel beyond the visible camera.
	level.keep_player_on_screen = false
	var ground: TileMapLayer = level.get_node("Layouts/GroundLayout")
	for x in range(-100, 101):
		ground.set_cell(Vector2i(x, 13), 0, Vector2i.ZERO)
		ground.set_cell(Vector2i(x, 14), 0, Vector2i.ZERO)

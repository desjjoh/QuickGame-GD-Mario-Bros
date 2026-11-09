extends RefCounted
## Creates the standard rising popup for an entity-selected reward.

const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")


static func show_score(
	parent: Node, points: int, world_position: Vector2, defer_first_draw := false
) -> Sprite2D:
	var popup := _create(parent)
	popup.show_score(points, world_position)
	popup.rise_and_free(defer_first_draw)
	return popup


static func show_one_up(
	parent: Node, world_position: Vector2, defer_first_draw := false
) -> Sprite2D:
	var popup := _create(parent)
	popup.show_one_up(world_position)
	popup.rise_and_free(defer_first_draw)
	return popup


static func _create(parent: Node) -> Sprite2D:
	var popup := SCORE_POPUP.instantiate() as Sprite2D
	parent.add_child(popup)
	return popup

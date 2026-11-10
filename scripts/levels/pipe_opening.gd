class_name PipeOpening
extends Node
## Authoring for a stage that starts at a castle and continues through a pipe.

@export var intro_area: BaseLevelArea
@export var castle_cell: Vector2i


func resolve_spawn(content: LevelAreaContent) -> Marker2D:
	var castle := content.find_layout_entity(intro_area, &"castle", castle_cell) as CastleEntity
	return castle.doorway if castle != null else null

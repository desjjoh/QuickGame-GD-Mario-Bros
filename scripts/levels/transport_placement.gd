@tool
class_name TransportPlacement
extends Resource
## Per painted anchor, never shared TileSet custom data.

@export var cell: Vector2i
@export var target_id: StringName
@export var destination: TransportDestination
@export var entrance_enabled: bool = true
@export var exit_enabled: bool = true
@export_range(1.0, 256.0, 1.0) var exit_distance: float = 96.0

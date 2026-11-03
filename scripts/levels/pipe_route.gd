@tool
class_name PipeRoute
extends Resource
## Temporary Inspector authoring for an individual painted pipe's destination.

@export var cell: Vector2i
@export var destination_area_id: StringName = &"lower"
@export var destination_endpoint_id: StringName = &"arrival"

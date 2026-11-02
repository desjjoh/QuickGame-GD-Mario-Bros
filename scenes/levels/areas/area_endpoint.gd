@tool
class_name AreaEndpoint
extends Marker2D
## Named arrival position. Direction is reserved for the emergence animation.

enum ExitDirection { UP, DOWN, LEFT, RIGHT }

@export var endpoint_id: StringName = &""
@export var exit_direction: ExitDirection = ExitDirection.UP


func get_endpoint_id() -> StringName:
	return endpoint_id if endpoint_id != &"" else StringName(name)

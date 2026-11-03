@tool
class_name TransportDestination
extends Resource
## An explicit area and target ID, independent of transport presentation.

@export var area_id: StringName
@export var target_id: StringName


static func create(area: StringName, target: StringName) -> TransportDestination:
	var destination := TransportDestination.new()
	destination.area_id = area
	destination.target_id = target
	return destination

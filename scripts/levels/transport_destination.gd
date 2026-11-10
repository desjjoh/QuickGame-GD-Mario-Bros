@tool
class_name TransportDestination
extends Resource
## An area endpoint or the stage to load after a warp.

@export var area_id: StringName
@export var target_id: StringName
@export var stage_scene: PackedScene


static func create(area: StringName, target: StringName) -> TransportDestination:
	var destination := TransportDestination.new()
	destination.area_id = area
	destination.target_id = target
	return destination

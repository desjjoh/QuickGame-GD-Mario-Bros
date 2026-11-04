extends RefCounted
## Standalone endpoint examples belong to test fixtures, not the playable stage.


static func add_to(level: BaseLevel) -> void:
	var parent := level.get_node("Areas/MainArea/Endpoints")
	for sample in [[&"near_start", Vector2(48, 208)], [&"near_end", Vector2(880, 208)]]:
		var marker := (
			load("res://scenes/levels/areas/area_endpoint.tscn").instantiate() as AreaEndpoint
		)
		marker.name = sample[0]
		marker.endpoint_id = sample[0]
		marker.position = sample[1]
		parent.add_child(marker)
		marker.owner = level

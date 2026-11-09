class_name TransportEntity
extends BaseEntity
## Shared source/arrival contract for pipes and future transport entities.

@export var transport_id: StringName
@export var destination: TransportDestination
@export var entrance_enabled: bool = true
@export var exit_enabled: bool = true
@export_range(1.0, 256.0, 1.0) var exit_distance: float = 96.0

var _level: BaseLevel


func _ready() -> void:
	_level = BaseLevel.containing(self)
	process_physics_priority = 50
	super()


func get_destination() -> TransportDestination:
	return destination


func can_start_transport(_player: BasePlayer) -> bool:
	return entrance_enabled and not is_shutdown


func get_transport_state(_player: BasePlayer) -> PlayerTransportState:
	return null


func entry_position() -> Vector2:
	return global_position


func entry_direction() -> Vector2:
	return Vector2.ZERO


func exit_position() -> Vector2:
	return global_position


func exit_direction() -> Vector2:
	return Vector2.ZERO

class_name PlayerTransportState
extends PlayerState
## Presentation contract; the level coordinates travel without owning its motion.

# Concrete transport states emit this inherited lifecycle signal.
@warning_ignore("unused_signal")

signal travel_finished


func configure(
	_position: Vector2,
	_direction: Vector2 = Vector2.DOWN,
	_emerging: bool = false,
	_distance: float = 0.0
) -> void:
	pass


func commit_transfer() -> void:
	pass

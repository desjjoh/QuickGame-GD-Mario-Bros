class_name SpawnableEntity
extends BaseEntity
## Reports a terminal gameplay outcome to the placement that spawned it.

signal consumed

## A repeating source can own camera retirement and replacement together.
var spawner_manages_activity := false


func report_consumed() -> void:
	consumed.emit()


func remove_offscreen() -> void:
	if not is_shutdown and not gameplay_suspended:
		queue_free()

class_name SpawnableEntity
extends BaseEntity
## Reports a terminal gameplay outcome to the placement that spawned it.

signal consumed


func report_consumed() -> void:
	consumed.emit()


func remove_offscreen() -> void:
	if not is_shutdown and not gameplay_suspended:
		queue_free()

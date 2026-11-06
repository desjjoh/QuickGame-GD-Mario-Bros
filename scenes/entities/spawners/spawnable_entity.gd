class_name SpawnableEntity
extends BaseEntity
## Reports a terminal gameplay outcome to the placement that spawned it.

signal consumed


func report_consumed() -> void:
	consumed.emit()

class_name WarpZonePipe
extends PipeEntrance

const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")

@export var display_text := "1"


func _ready() -> void:
	super()
	# The player draws after area signage at this priority. The pipe stays above both.
	DRAW_ORDER.apply($WorldNumber, DRAW_ORDER.BEHIND_WORLD)
	$WorldNumber.text = display_text
	$WorldNumber.hide()
	entrance_enabled = false


func reveal() -> void:
	$WorldNumber.show()
	entrance_enabled = destination != null
	var spawner := get_node_or_null("OccupantSpawner") as EntitySpawner
	if spawner != null:
		spawner.shutdown()
		BaseEntity.shutdown_descendants(spawner)
		spawner.hide()
		spawner.queue_free()

class_name BlockHitReceiver
extends Area2D
## A narrow foot contact used by blocks that are struck from below.

signal hit_received(hit: EntityHit)

const QUERY_LAYER := 1 << 9


func receive_hit(hit: EntityHit) -> void:
	hit_received.emit(hit)

extends EnemyDefeatedState


func _apply_launch_pose() -> void:
	entity.sprite.vframes = 2
	entity.sprite.frame = 4
	entity.sprite.position = Vector2.ZERO if fireball_launch or star_launch else Vector2(0, 2)
	super()
	if star_launch:
		# Starman's defeated shell uses the upright tiles on the reveal update.
		entity.sprite.flip_v = false

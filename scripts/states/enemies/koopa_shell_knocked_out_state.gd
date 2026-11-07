extends EnemyDefeatedState


func enter() -> void:
	entity.sprite.vframes = 2
	entity.sprite.frame = 4
	entity.sprite.position = Vector2(0, 2)
	super.enter()

extends Mushroom

const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")


func _grant_reward(_player: BasePlayer) -> void:
	var pickup_position := sprite.global_position
	var popup := SCORE_POPUP.instantiate()
	get_parent().add_child(popup)
	popup.show_one_up(pickup_position)
	popup.rise_and_free()

	GameHandler.set_lives(GameHandler.player_status.lives + 1)
	SoundHandler.play_reward(&"extra_life")

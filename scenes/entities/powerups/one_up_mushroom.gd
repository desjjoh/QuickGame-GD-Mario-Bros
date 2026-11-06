extends Mushroom

const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")
const POPUP_RISE := 24.0
const POPUP_DURATION := 0.8


func _grant_reward() -> void:
	var pickup_position := sprite.global_position
	var popup := SCORE_POPUP.instantiate()
	get_parent().add_child(popup)
	popup.show_one_up(pickup_position)
	var float_up := popup.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	float_up.tween_property(popup, "position:y", popup.position.y - POPUP_RISE, POPUP_DURATION)
	float_up.tween_callback(popup.queue_free)

	GameHandler.set_lives(GameHandler.player_status.lives + 1)
	SoundHandler.play_reward(&"extra_life")

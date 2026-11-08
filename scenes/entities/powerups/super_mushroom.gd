class_name SuperMushroom
extends Mushroom

const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")


func _begin_collection(player: BasePlayer) -> bool:
	var mario := player as Mario
	if mario == null or mario.form_presentation.active:
		return false
	if mario.form_controller.current_form == MarioFormPresentation.SMALL:
		return mario.grow()
	# Approved temporary behavior until Fire is implemented: points, keep Super.
	return mario.form_controller.current_form == MarioFormPresentation.SUPER


func _grant_reward(_player: BasePlayer) -> void:
	var popup := SCORE_POPUP.instantiate()
	get_parent().add_child(popup)
	popup.show_score(1000, sprite.global_position)
	var rise := popup.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_property(popup, "position:y", popup.position.y - 24.0, 0.8)
	rise.tween_callback(popup.queue_free)
	GameHandler.add_score(1000)
	SoundHandler.play_reward(&"power_up_grab")

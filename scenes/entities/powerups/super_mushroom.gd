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
	popup.rise_and_free()
	GameHandler.add_score(1000)
	SoundHandler.play_reward(&"power_up_grab")

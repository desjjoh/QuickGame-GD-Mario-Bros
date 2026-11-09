extends PowerUp

const DELAYED_REWARD := preload("res://scenes/components/interactions/delayed_reward.gd")
const RISING_REWARD_POPUP := preload("res://scenes/components/presentation/rising_reward_popup.gd")


func _ready() -> void:
	super()
	$Presentation/PaletteAnimation.set_enabled(true)


func _begin_collection(player: BasePlayer) -> bool:
	var mario := player as Mario
	if mario == null or mario.form_presentation.active:
		return false
	var form := mario.form_controller.current_form
	if form == mario.small_form:
		return mario.grow()
	if form == mario.super_form:
		return mario.ignite()
	return form == mario.fire_form


func _grant_reward(_player: BasePlayer) -> void:
	RISING_REWARD_POPUP.show_score(get_parent(), 1000, sprite.global_position)
	DELAYED_REWARD.schedule(self, GameHandler.add_score.bind(1000))
	SoundHandler.play_reward(&"power_up_grab")

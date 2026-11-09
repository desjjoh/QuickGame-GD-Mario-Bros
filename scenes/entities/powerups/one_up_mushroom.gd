extends Mushroom

const DELAYED_REWARD := preload("res://scenes/components/interactions/delayed_reward.gd")
const RISING_REWARD_POPUP := preload("res://scenes/components/presentation/rising_reward_popup.gd")


func _grant_reward(_player: BasePlayer) -> void:
	RISING_REWARD_POPUP.show_one_up(get_parent(), sprite.global_position)
	DELAYED_REWARD.schedule(self, _award_life)


static func _award_life() -> void:
	GameHandler.set_lives(GameHandler.player_status.lives + 1)
	SoundHandler.play_reward(&"extra_life")

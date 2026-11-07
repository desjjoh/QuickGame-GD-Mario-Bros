class_name Mario
extends BasePlayer
## Concrete player character with its own states and animation cadence.

@onready var walk_animation: WalkAnimationComponent = $Presentation/WalkAnimation


func update_scripted_walk_animation() -> void:
	if animation_player.current_animation != &"walk":
		animation_player.play(&"walk")
	walk_animation.apply(animation_player, body.velocity.x)

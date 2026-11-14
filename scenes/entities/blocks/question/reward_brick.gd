extends QuestionBlock
## Reward bricks share the question block's states with a static active sprite.

@export var brick_texture: Texture2D


func _ready() -> void:
	var active := $StateMachine/Active as EntityState
	active.synchronized_animation = null
	active.sprite_texture = brick_texture
	active.stop_animation_on_enter = true
	super()

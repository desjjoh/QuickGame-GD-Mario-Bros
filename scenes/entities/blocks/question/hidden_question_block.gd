class_name HiddenQuestionBlock
extends QuestionBlock

const REVEALED_TEXTURE := preload(
	"res://assets/palettes/overworld/interactibles/blocks/question-block.tres"
)

@onready var _probe: Area2D = $BonkProbe


func _ready() -> void:
	$StateMachine/Active.synchronized_animation = null
	if reward_started:
		_set_revealed_texture()
	$StateMachine/Bouncing.entered.connect(_reveal)
	super()
	if state_machine.current_state.name == &"Inactive" or reward_started:
		_reveal()


func _reveal() -> void:
	_set_revealed_texture()
	body.set_deferred("collision_layer", 1)
	_probe.set_deferred("collision_layer", 0)


func _set_revealed_texture() -> void:
	$StateMachine/Active.sprite_texture = (
		visual_theme.resolve_texture(REVEALED_TEXTURE) if visual_theme else REVEALED_TEXTURE
	)

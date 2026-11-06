class_name HiddenQuestionBlock
extends QuestionBlock

@onready var _probe: Area2D = $BonkProbe


func _ready() -> void:
	$StateMachine/Active.synchronized_animation = null
	$StateMachine/Bouncing.entered.connect(_reveal)
	super()
	if state_machine.current_state.name == &"Inactive":
		_reveal()


func _reveal() -> void:
	body.set_deferred("collision_layer", 1)
	_probe.set_deferred("collision_layer", 0)

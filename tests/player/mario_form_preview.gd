extends Node
## F6 visual preview; no gameplay rewards, damage, or new input bindings.


func _ready() -> void:
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = MarioFormPresentation.SMALL
	level.timer_enabled = false
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	var mario := level.player as Mario
	mario.controller_input_enabled = false
	while not mario.is_dead and not mario.is_shutdown:
		await get_tree().create_timer(1.0, false).timeout
		if not mario.grow():
			return
		await mario.form_presentation.finished
		await get_tree().create_timer(1.0, false).timeout
		if not mario.shrink():
			return
		await mario.form_presentation.finished

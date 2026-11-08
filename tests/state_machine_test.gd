extends Node
## Run with Godot --headless --path . tests/state_machine_test.tscn


class ProbeState:
	extends PlayerState
	var calls: Array[String] = []
	var next_state: BaseState
	var transitions_on_enter: bool = false
	var shutdown_on_enter: bool = false

	func enter() -> void:
		calls.append("enter")
		if shutdown_on_enter:
			entity.shutdown()
		if next_state != null:
			transitions_on_enter = state_machine.change_state(next_state)

	func exit() -> void:
		calls.append("exit")

	func update(_delta: float) -> BaseState:
		calls.append("update")
		return next_state

	func process_physics(_delta: float) -> BaseState:
		calls.append("physics")
		return null

	func process_input(_event: InputEvent) -> BaseState:
		calls.append("input")
		return null

	func animation_finished(_animation: StringName) -> BaseState:
		calls.append("animation_finished")
		return null


func _ready() -> void:
	call_deferred("run_checks")


func make_entity(parent: Node = null) -> BaseEntity:
	var entity: BaseEntity = load("res://scenes/entities/base/base_entity.tscn").instantiate()
	entity.sprite = Sprite2D.new()
	entity.add_child(entity.sprite)
	entity.animation_player = AnimationPlayer.new()
	entity.add_child(entity.animation_player)
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", Animation.new())
	entity.animation_player.add_animation_library(&"", library)
	var machine: EntityStateMachine = entity.get_node("StateMachine")
	var first := ProbeState.new()
	first.name = "First"
	first.animation_name = &"idle"
	first.sprite_tint = Color.RED
	var second := ProbeState.new()
	second.name = "Second"
	second.sprite_offset = Vector2(2, 0)
	second.controls_enabled = false
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(800)
	samples.fill(128)
	sound.data = samples
	first.enter_sound_effect = sound
	first.exit_sound_effect = sound
	machine.add_child(first)
	machine.add_child(second)
	machine.initial_state = first
	if parent == null:
		parent = get_tree().root
	parent.add_child(entity)
	return entity


func run_checks() -> void:
	var one := make_entity()
	var two := make_entity()
	var machine := one.state_machine
	var first := machine.get_state(&"First") as ProbeState
	var second := machine.get_state(&"Second") as ProbeState
	assert(machine.current_state == first)
	assert(first.entity == one and two.state_machine.current_state.entity == two)
	assert(first.calls == ["enter"])
	assert(one.sprite.modulate == Color.RED)
	assert(one.animation_player.current_animation == "idle")
	assert(one.find_children("*", "AudioStreamPlayer", false, false).size() == 1)
	var lifecycle_events: Array[String] = []
	first.exited.connect(func(): lifecycle_events.append("first_exited"))
	second.entered.connect(func(): lifecycle_events.append("second_entered"))
	machine.state_changed.connect(
		func(_old: BaseState, _new: BaseState): lifecycle_events.append("changed")
	)
	assert(machine.change_state(first))
	assert(first.calls == ["enter"], "Same-state requests must not re-enter.")
	assert(not machine.change_state(null))
	machine.process_input(InputEventKey.new())
	machine.process_physics(0.016)
	assert(first.calls == ["enter", "input", "physics"])
	first.frame_updates_enabled = false
	machine.update(0.016)
	assert(not first.calls.has("update"))
	first.frame_updates_enabled = true
	first.next_state = second
	second.next_state = first
	machine.update(0.016)
	assert(machine.current_state == second)
	assert(first.calls == ["enter", "input", "physics", "update", "exit"])
	assert(second.calls == ["enter"])
	assert(lifecycle_events == ["first_exited", "second_entered", "changed"])
	assert(one.find_children("*", "AudioStreamPlayer", false, false).size() == 2)
	var audio: AudioStreamPlayer = one.find_children("*", "AudioStreamPlayer", false, false)[0]
	assert(
		not audio.playing and audio.is_queued_for_deletion(),
		"New effects must stop the previous entity sound immediately."
	)
	audio.finished.emit()
	assert(audio.is_queued_for_deletion())
	assert(not second.transitions_on_enter, "Nested transitions must be rejected.")
	assert(one.sprite.modulate == Color.WHITE and one.sprite.offset == Vector2(2, 0))
	assert(two.state_machine.current_state.name == "First")
	machine.process_input(InputEventKey.new())
	assert(not second.calls.has("input"), "Disabled controls must block input forwarding.")
	one.animation_player.animation_finished.emit(&"idle")
	assert(second.calls.has("animation_finished"))
	second.physics_updates_enabled = false
	machine.process_physics(0.016)
	assert(not second.calls.has("physics"))
	machine.stop()
	machine.stop()
	assert(machine.current_state == null and second.calls.count("exit") == 1)
	assert(machine.start() and machine.current_state == first)
	var sounds_before := one.find_children("*", "AudioStreamPlayer", false, false).size()
	var exits_before := first.calls.count("exit")
	one.shutdown()
	one.shutdown()
	assert(first.calls.count("exit") == exits_before + 1)
	assert(machine.current_state == null and not machine.start())
	assert(not machine.change_state(second))
	assert(not ControllerHandler.input_received.is_connected(machine.process_input))
	assert(not one.animation_player.animation_finished.is_connected(machine.on_animation_finished))
	assert(
		one.find_children("*", "AudioStreamPlayer", false, false).size() == sounds_before,
		"Shutdown must skip exit presentation."
	)
	for effect: AudioStreamPlayer in one.find_children("*", "AudioStreamPlayer", false, false):
		assert(not effect.playing)
	var calls_after := first.calls.duplicate()
	one._process(0.016)
	one._physics_process(0.016)
	machine.process_input(InputEventKey.new())
	assert(first.calls == calls_after)
	var two_state := two.state_machine.current_state as ProbeState
	get_tree().root.remove_child(two)
	assert(
		two.is_shutdown and two_state.calls.count("exit") == 1,
		"Tree removal must perform fallback cleanup."
	)
	one.free()
	two.free()
	var reentrant := make_entity()
	var reentrant_state := reentrant.state_machine.current_state as ProbeState
	reentrant.state_machine.stop()
	reentrant_state.shutdown_on_enter = true
	reentrant.state_machine.start()
	assert(reentrant.is_shutdown and reentrant.state_machine.current_state == null)
	assert(reentrant_state.calls.count("exit") == 2)
	reentrant.free()
	var game: Node = load("res://tests/fixtures/silent_game.tscn").instantiate()
	get_tree().root.add_child(game)
	var level: BaseLevel = game.get_node("LevelContainer").get_child(0)
	assert(level.player is Mario)
	assert(level.player.state_machine.current_state is MarioIdleState)
	assert(level.player.sprite != null and level.player.sprite.texture != null)
	assert(GameHandler.current_level == level and GameHandler.current_player == level.player)
	GameHandler.set_session_value(&"test_score", 100)
	var previous_player := level.player
	previous_player.body.velocity.x = 150.0
	previous_player.state_machine.change_state(previous_player.state_machine.get_state(&"Slide"))
	assert(
		(
			previous_player.motion_values.acceleration
			!= previous_player.motion_values.base_acceleration
		)
	)
	var nested := make_entity(level.players)
	var nested_state := nested.state_machine.current_state as ProbeState
	level.tree_exiting.connect(
		func(): assert(previous_player.is_shutdown, "Cleanup must precede level removal.")
	)
	assert(GameHandler.load_level(load("res://tests/fixtures/silent_level.tscn")))
	assert(level.is_shutdown and previous_player.is_shutdown)
	assert(previous_player.state_machine.current_state == null)
	assert(
		(
			previous_player.motion_values.acceleration
			== previous_player.motion_values.base_acceleration
		)
	)
	assert(level.spawn_player() == null)
	assert(nested.is_shutdown and nested_state.calls.count("exit") == 1)
	assert(GameHandler.current_level != level)
	assert(GameHandler.current_player != previous_player)
	assert(GameHandler.get_session_value(&"test_score") == 100)
	assert(
		not ControllerHandler.input_received.is_connected(
			previous_player.state_machine.process_input
		)
	)
	var base: BasePlayer = load("res://scenes/player/base/base_player.tscn").instantiate()
	get_tree().root.add_child(base)
	assert(base.state_machine.current_state == null)
	base.free()
	ControllerHandler.input_right = 1.0
	assert(ControllerHandler.get_axis() == Vector2.RIGHT)
	var idle := GameHandler.current_player.state_machine.current_state as PlayerState
	assert(idle.get_movement_axis() == Vector2.RIGHT)
	idle.controls_enabled = false
	assert(idle.get_movement_axis() == Vector2.ZERO)
	ControllerHandler.enabled = false
	assert(ControllerHandler.get_axis() == Vector2.ZERO)
	ControllerHandler.enabled = true
	GameHandler.clear_session()
	game.free()
	assert(GameHandler.current_game == null and GameHandler.current_level == null)
	print(
		"PASS: state transitions, presentation, isolated entities, Mario-owned Idle, global game ownership, level replacement, session data, and controller permissions."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

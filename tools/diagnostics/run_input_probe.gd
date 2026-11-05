extends Node
## Opt-in input/motion recorder. F7 marks the moment Run feels lost; F8 saves.

var _game: Node
var _label: Label
var _rows: Array[PackedStringArray] = []
var _events: Array[String] = []
var _last_signature: String
var _start_ms: int
var _saved: bool = false


func _ready() -> void:
	process_physics_priority = 1000
	_start_ms = Time.get_ticks_msec()
	_game = load("res://scenes/main/game.tscn").instantiate()
	add_child(_game)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	_label = Label.new()
	_label.position = Vector2(4, 48)
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override(&"shadow_offset_x", 1)
	_label.add_theme_constant_override(&"shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_label)
	Input.joy_connection_changed.connect(_on_connection)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_events.append(
			(
				"pad%s button%s %s"
				% [event.device, event.button_index, "down" if event.pressed else "up"]
			)
		)
	elif event is InputEventKey and not event.echo:
		if event.is_action(ControllerHandler.secondary_action):
			_events.append("keyboard Run %s" % event.pressed)
		if event.pressed and event.physical_keycode == KEY_F7:
			_events.append("USER MARK: Run felt lost")
		if event.pressed and event.physical_keycode == KEY_F8:
			_save()
			get_tree().quit()


func _on_connection(device: int, connected: bool) -> void:
	_events.append("pad%s connected=%s" % [device, connected])


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_events.append("application focus lost")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_events.append("application focus gained")


func _physics_process(_delta: float) -> void:
	if _label == null:
		return
	var pads: Array[String] = []
	for device in Input.get_connected_joypads():
		pads.append("%s:%s" % [device, int(Input.is_joy_button_pressed(device, JOY_BUTTON_X))])
	var mapped := Input.is_action_pressed(ControllerHandler.secondary_action)
	var player := GameHandler.current_player
	var state := "none"
	var grounded := false
	var velocity := 0.0
	var cap := 0.0
	var gate := false
	var modifiers := ""
	if is_instance_valid(player):
		state = (
			str(player.state_machine.current_state.name)
			if player.state_machine.current_state != null
			else "none"
		)
		grounded = player.body.is_on_floor()
		velocity = player.body.velocity.x
		cap = player.motion_values.max_speed
		gate = player.can_read_controller_input()
		modifiers = str(player.motion_values._modifiers.keys())
	var raw := ",".join(pads)
	var signature := (
		"%s|%s|%s|%s|%s|%s|%s"
		% [raw, mapped, ControllerHandler.input_secondary, gate, state, grounded, cap]
	)
	# Record changes and explicit events, avoiding disk writes during play.
	if signature != _last_signature or not _events.is_empty():
		_rows.append(
			PackedStringArray(
				[
					str(Time.get_ticks_msec() - _start_ms),
					raw,
					str(mapped),
					str(ControllerHandler.input_secondary),
					str(ControllerHandler.enabled),
					str(gate),
					state,
					str(grounded),
					str(velocity),
					str(cap),
					modifiers,
					"; ".join(_events)
				]
			)
		)
		_last_signature = signature
		_events.clear()
	_label.text = (
		"""RUN PROBE  F7 mark / F8 save
Pad X [%s] action:%s handler:%s
State:%s floor:%s controls:%s
Speed:%.1f cap:%.1f
%s"""
		% [
			raw,
			int(mapped),
			int(ControllerHandler.input_secondary),
			state,
			int(grounded),
			int(gate),
			velocity,
			cap,
			modifiers
		]
	)
	if Time.get_ticks_msec() - _start_ms >= 180000:
		_save()
		get_tree().quit()


func _save() -> void:
	if _saved:
		return
	_saved = true
	DirAccess.make_dir_recursive_absolute("user://diagnostics")
	var path := "user://diagnostics/run-input-%s.csv" % Time.get_ticks_usec()
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot save Run input capture: %s" % FileAccess.get_open_error())
		return
	output.store_csv_line(
		PackedStringArray(
			[
				"elapsed_ms",
				"pad_x_by_device",
				"mapped_run",
				"handler_run",
				"handler_enabled",
				"player_input_gate",
				"state",
				"grounded",
				"velocity_x",
				"effective_max_speed",
				"modifiers",
				"events"
			]
		)
	)
	for row in _rows:
		output.store_csv_line(row)
	output.close()
	print("RUN INPUT CAPTURE: ", ProjectSettings.globalize_path(path))


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_connection):
		Input.joy_connection_changed.disconnect(_on_connection)
	_save()

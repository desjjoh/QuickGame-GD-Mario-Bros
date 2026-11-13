extends Node

const LEVEL := preload("res://tests/fixtures/silent_level.tscn")
const SPAWNER := preload("res://scenes/entities/spawners/fire_bar_spawner.tscn")
const FINISH := preload("res://tests/fixtures/finish_test.gd")

var _area: BaseLevelArea
var _camera: LevelCamera


func _ready() -> void:
	var level := LEVEL.instantiate() as BaseLevel
	var objects := level.get_node("Areas/MainArea/WorldObjects")
	_add_source(objects, &"ShortBar", Vector2(488, 120), FireBar.Length.SHORT)
	_add_source(objects, &"UpperBar", Vector2(488, 48), FireBar.Length.LONG)
	_add_source(objects, &"LowerBar", Vector2(488, 200), FireBar.Length.LONG)
	add_child(level)
	await get_tree().process_frame
	level.player.set_physics_process(false)
	level.spawn_registry.enemy_limit = 0
	_area = level.active_area
	_camera = _area.get_node("Camera2D") as LevelCamera
	_camera.set_process(false)
	_camera.set_physics_process(false)
	_scroll(480.0)
	objects = _area.get_node("WorldObjects")
	var short := objects.get_node("ShortBar/FireBar") as FireBar
	var upper := objects.get_node("UpperBar/FireBar") as FireBar
	var lower := objects.get_node("LowerBar/FireBar") as FireBar
	assert(short != null and upper != null and lower != null)

	for bar: FireBar in [short, upper, lower]:
		bar.set_physics_process(false)
		assert(level.spawn_registry.get_slot(&"enemy", bar) == -1)
		var segments := bar.get_node("Presentation").get_children()
		assert(segments.size() == (6 if bar == short else 12))
		assert((segments.front() as Sprite2D).global_position == bar.get_parent().global_position)
		var half_width := _view().size.x / 2.0
		var pivot_x := bar.global_position.x + FireBar.PIVOT.x
		_scroll(pivot_x - half_width + 16.0)
		await _check_partial(bar, segments, 9 if bar != short else 8)
		_scroll(pivot_x + half_width - 16.0)
		await _check_partial(bar, segments, 25 if bar != short else 24)
		if bar != short:
			_scroll(pivot_x)
			await _check_partial(bar, segments, 0 if bar == upper else 16)

		_scroll(pivot_x + half_width + 128.0)
		var phase_before := bar.phase
		bar._physics_process(0.0)
		await get_tree().process_frame
		assert(is_instance_valid(bar) and not bar.is_queued_for_deletion())
		assert(not bar.visible and bar.phase == phase_before)
		assert(bar.get_node("Presentation").get_children() == segments)

		_scroll(pivot_x)
		bar._physics_process(0.0)
		assert(bar.visible and bar.phase != phase_before)
		assert(bar.get_node("Presentation").get_children() == segments)

	await _check_scrolling_contact(level.player as Mario, short)
	await _check_landing_after_bonk(level.player as Mario, short)
	level.free()
	print("PASS: Fire Bar retention and previous-frame screen-relative contact.")
	await FINISH.finish(get_tree())


func _add_source(parent: Node, label: StringName, pivot: Vector2, length: FireBar.Length) -> void:
	var source := SPAWNER.instantiate() as FireBarSpawner
	source.name = label
	source.position = pivot
	source.length = length
	parent.add_child(source)


func _scroll(center_x: float) -> void:
	_camera.global_position.x = center_x
	_area.update_camera_activity()


func _view() -> Rect2:
	return _area.get_activity_region(false).grow(-_area.activation_buffer)


func _check_scrolling_contact(mario: Mario, bar: FireBar) -> void:
	# Mesen scroll trace at the first 1-4 bar. The actor origin is the tile top-left.
	bar.global_position = Vector2(480, 160)
	var samples := [
		[472, 315, 132, 5912, false],
		[473, 317, 133, 5872, true],
		[486, 343, 135, 5352, true],
		[487, 345, 136, 5312, false],
		[488, 347, 137, 5272, false],
	]
	for index in range(samples.size()):
		# The two groups are independent excerpts with a break in frame history.
		if index == 2:
			await get_tree().physics_frame
		await get_tree().physics_frame
		var sample: Array = samples[index]
		_scroll(sample[1] + _view().size.x / 2.0)
		var view := _view()
		mario.body.global_position = Vector2(sample[0] + 8, sample[2] + 32)
		bar.phase = sample[3]
		var probe_x := bar._sample_player_probe_x(mario, view)
		if index in [1, 3, 4]:
			var prior: Array = samples[index - 1]
			assert(probe_x == prior[0] - prior[1] + 4)
			assert(
				bar.touches_player(mario.body.global_position.y, true, view, probe_x) == sample[4]
			)
	# The top probe is live on the contact frame and belongs only to standing Super Mario.
	bar.phase = 8 << 8
	var pivot_screen_x := 484 - floori(_view().position.x)
	assert(bar.touches_player(196, false, _view(), pivot_screen_x))
	assert(not bar.touches_player(196, true, _view(), pivot_screen_x))


func _check_landing_after_bonk(mario: Mario, bar: FireBar) -> void:
	# 1-4 at X783, after bonking the solid block at (49, 6).
	# The first arm segment is at (794, 104). The supported head probe is at Y112.
	bar.global_position = Vector2(784, 96)
	bar.phase = 3056
	var view := Rect2(643, 0, 256, 240)
	var probe_x := 783 - 643 + 4
	for form in [mario.super_form, mario.fire_form]:
		mario.form_controller.configure(mario, form)
		mario.body.global_position = Vector2(791, 143.99997)
		mario._floor_supported = true
		mario._floor_position = mario.body.global_position
		assert(FireBar.player_feet_y(mario) == 144.0)
		assert(not bar.touches_player(FireBar.player_feet_y(mario), false, view, probe_x))
		mario._floor_supported = false
		assert(FireBar.player_feet_y(mario) < 144.0)
		assert(bar.touches_player(FireBar.player_feet_y(mario), false, view, probe_x))
		await get_tree().physics_frame


func _check_partial(bar: FireBar, segments: Array[Node], angle: int) -> void:
	bar.phase = angle << 8
	var phase_before := bar.phase
	bar._physics_process(0.0)
	var pivot := segments.front() as Sprite2D
	var tip := segments.back() as Sprite2D
	assert(_view().has_point(pivot.global_position))
	assert(not _view().intersects(Rect2(tip.global_position - Vector2(4, 4), Vector2(8, 8))))
	await get_tree().process_frame
	assert(is_instance_valid(bar) and not bar.is_queued_for_deletion())
	assert(bar.visible and bar.phase != phase_before)
	assert(bar.get_node("Presentation").get_children() == segments)

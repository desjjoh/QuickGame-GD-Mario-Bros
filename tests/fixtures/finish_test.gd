extends RefCounted
## AudioServer releases stopped playback on its mix thread, not the scene clock.


static func finish(tree: SceneTree) -> void:
	if tree.has_meta(&"test_finish_pending"):
		return
	tree.set_meta(&"test_finish_pending", true)
	if is_instance_valid(tree.current_scene):
		tree.current_scene.set_process(false)
		tree.current_scene.set_physics_process(false)
	tree.paused = true
	if not await drain_audio(tree):
		tree.quit(1)
		return
	tree.quit()


static func drain_audio(tree: SceneTree) -> bool:
	_stop_audio(tree.root)
	var previous := AudioServer.get_time_since_last_mix()
	var mixes := 0
	var deadline := Time.get_ticks_msec() + 1000
	while mixes < 2 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		# Fixed-FPS tests may otherwise consume their frame limit before audio runs.
		OS.delay_msec(1)
		var current := AudioServer.get_time_since_last_mix()
		if current < previous:
			mixes += 1
		previous = current
	if mixes < 2:
		push_error("Test teardown timed out waiting for two audio mix boundaries.")
		return false
	return true


static func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
	for child in node.get_children():
		_stop_audio(child)

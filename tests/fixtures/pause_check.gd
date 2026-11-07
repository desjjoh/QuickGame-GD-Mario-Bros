extends RefCounted
## Run from an Always-processing test harness with a Pausable game fixture.


static func snapshot(level: BaseLevel) -> Array:
	return [
		level.player.body.global_position if is_instance_valid(level.player) else Vector2.ZERO,
		(
			level.player.animation_player.current_animation_position
			if (
				is_instance_valid(level.player)
				and level.player.animation_player.current_animation != &""
			)
			else 0.0
		),
		GameHandler.animation_clock.tick_count,
		GameHandler.time_remaining,
		GameHandler.player_status.score,
		level.death_sequence._elapsed,
		level.area_transport._transport_phase,
		level.ending_presentation.phase if level.ending_presentation != null else -1,
	]


static func check(level: BaseLevel) -> void:
	assert(GameHandler.request_pause_toggle())
	var before := snapshot(level)
	for frame in range(8):
		await level.get_tree().process_frame
	assert(GameHandler.current_level == level)
	assert(snapshot(level) == before)
	assert(GameHandler.request_pause_toggle())

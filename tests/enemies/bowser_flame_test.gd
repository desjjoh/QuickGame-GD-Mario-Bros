extends Node

const LEVEL := preload("res://scenes/levels/worlds/world 1/1-4.tscn")
const FINISH := preload("res://tests/fixtures/finish_test.gd")
const STEP := 1.0 / 60.0


func _ready() -> void:
	var level := LEVEL.instantiate() as BaseLevel
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	var area := level.active_area
	area.set_physics_process(false)
	var camera := area.get_node("Camera2D") as LevelCamera
	var source := level.world_objects.get_node("BowserFlameSource") as BowserFlameSource
	source.set_physics_process(false)
	camera.global_position.x = 1360 + 128
	source._physics_process(STEP)
	assert(source.get_child_count() == 0)
	camera.global_position.x = 1362 + 128
	source._physics_process(STEP)
	assert(source.get_child_count() == 1 and source._early_ticks == 223)
	assert(source._flame_cue_pending and not source._flame_voice.playing)
	assert(source._flame_voice.volume_db == 0.0)
	assert(source._flame_voice.stream == SoundHandler.get_sound(&"bowser_flame"))
	var early := source.get_child(0) as BowserFlame
	early.set_physics_process(false)
	assert(early.body.global_position.x == 1649)
	var early_y := early.body.global_position.y
	assert(roundi(early_y) in BowserFlameSource.HEIGHTS)
	for x in [1647, 1646, 1645, 1644, 1642]:
		early._physics_process(STEP)
		assert(early.body.global_position == Vector2(x, early_y))

	camera.global_position.x = 2022 + 128
	var spawner := level.world_objects.get_node("BowserSpawner") as EntitySpawner
	spawner.update_activity(
		area.get_enemy_spawn_region(), area.get_activity_region(true), area.theme
	)
	var boss := spawner.get_node("Bowser") as Bowser
	boss.set_physics_process(false)
	boss.body.global_position = Vector2(2204, 101)
	source._physics_process(STEP)
	assert(boss.flame_source == source)
	assert(source._flame_voice.playing and not source._flame_cue_pending)
	assert(source.get_child_count() == 1 and is_instance_valid(early))
	# The earlier launch consumed index zero. The first breath consumes index one.
	boss._mouth_open = true
	boss._breath_ticks = 1
	boss._jump_ticks = 10
	boss._advance_patrol(STEP, 1, 2000)
	assert(boss._breath_ticks == 64)
	source._physics_process(STEP)
	assert(source.get_child_count() == 1)
	source._early_ticks = 1
	source._physics_process(STEP)
	var breath := source.get_child(1) as BowserFlame
	assert(source._flame_cue_pending)
	source._flame_voice.stop()
	source._physics_process(STEP)
	assert(source._flame_voice.playing and not source._flame_cue_pending)
	breath.set_physics_process(false)
	assert(breath.body.global_position == Vector2(2190, 109))
	# Replay the captured lane choice independently of Godot's random sequence.
	breath.target_world_y = 112.0
	for expected in [
		Vector2(2188, 110), Vector2(2187, 111), Vector2(2186, 112), Vector2(2185, 112)
	]:
		breath._physics_process(STEP)
		assert(breath.body.global_position == expected)
	assert(breath.projectile_target_bounds() == Rect2(2191, 116, 4, 4))
	assert(not breath.receive_hit(EntityHit.new(level.player, &"fireball", Vector2.RIGHT)))
	assert(is_instance_valid(early) and source.get_child_count() == 2)
	level.completion_in_progress = true
	source._physics_process(STEP)
	assert(early.is_queued_for_deletion() and breath.is_queued_for_deletion())
	level.queue_free()
	await get_tree().process_frame
	print("PASS: Bowser flame spawn, shared timer, handoff, and Mesen motion.")
	await FINISH.finish(get_tree())

extends Node

const STAGE := preload("res://scenes/levels/worlds/world 1/1-4.tscn")
const CONTACT := preload("res://scenes/components/interactions/player_contact.gd")
const FINISH := preload("res://tests/fixtures/finish_test.gd")
const BOWSER := preload("res://scenes/entities/enemies/bowser/bowser.tscn")
const SHOT := preload("res://scenes/entities/projectiles/fireball.tscn")
const STEP := 1.0 / 60.0


func _ready() -> void:
	var level := STAGE.instantiate() as BaseLevel
	level.player_start_configuration = preload("res://assets/player/forms/super.tres")
	add_child(level)
	var area := level.active_area
	var camera := area.get_node("Camera2D") as LevelCamera
	var spawner := level.world_objects.get_node("BowserSpawner") as EntitySpawner
	assert(spawner.get_child_count() == 1)
	camera.follow_enabled = false
	camera.global_position.x = 2150
	area.update_camera_activity()
	var boss := spawner.get_node("Bowser") as Bowser
	assert(boss.body.global_position == Vector2(2160, 128))
	assert(boss.sprite.texture.resource_path.contains("/castle/"))
	assert(level.spawn_registry.get_slot(&"enemy", boss) >= 0)
	boss.set_physics_process(false)
	area.set_physics_process(false)
	var mario := level.player as Mario
	mario.set_physics_process(false)

	_check_spawn_step(boss)
	_check_jump(boss)
	_check_facing_and_mouth(boss)
	_check_contact(boss, mario)
	await _check_damage(boss, mario)
	mario.form_presentation.cancel()
	await _check_fireballs(level, boss, mario)
	level.queue_free()
	await get_tree().process_frame
	print("PASS: Bowser movement, player contact, and fireball defeat match Mesen.")
	await FINISH.finish(get_tree())


func _check_spawn_step(boss: Bowser) -> void:
	# The spawn trace starts at frame 116. The first movement is on frame 120.
	for frame in range(117, 120):
		boss._advance_patrol(STEP, frame, 2009)
		assert(boss.body.global_position == Vector2(2160, 128))
	boss._advance_patrol(STEP, 120, 2009)
	assert(boss.body.global_position == Vector2(2162, 128))
	assert(boss.sprite.flip_h)


func _check_jump(boss: Bowser) -> void:
	# Mesen patrol trace, starting at sample 1 after the player was parked left.
	boss.body.position = Vector2(54, 0)
	boss._patrol_range = 65
	boss._jump_ticks = 7
	boss._feet_ticks = 17
	boss._vertical.position_fraction = 129
	boss._alternate_feet = true
	boss._direction = Bowser.FACE_LEFT
	var expected := {
		2: Vector2(2216, 128),
		6: Vector2(2218, 128),
		7: Vector2(2218, 127),
		8: Vector2(2218, 125),
		12: Vector2(2220, 118),
		22: Vector2(2226, 103),
		26: Vector2(2225, 99),
		42: Vector2(2221, 92),
		69: Vector2(2215, 114),
		76: Vector2(2213, 126),
		77: Vector2(2213, 129),
	}
	for tick in range(2, 78):
		boss._advance_patrol(STEP, (226 + tick) & 255, 2090)
		if expected.has(tick):
			assert(boss.body.global_position == expected[tick], "Mesen patrol sample %s" % tick)
	assert(boss._patrol_step == -1)
	assert(boss._jump_ticks in Bowser.PATROL_RANGES)
	assert(boss._vertical.position_fraction == 2)


func _check_facing_and_mouth(boss: Bowser) -> void:
	# Mesen rear-side sample 111 → 112.
	boss.body.position = Vector2(52, 1)
	boss._jump_ticks = 33
	boss._advance_patrol(STEP, 82, 2220)
	assert(boss.body.global_position == Vector2(2212, 129))
	assert(boss.sprite.flip_h and boss._jump_ticks == 32 and boss._breath_ticks == 32)
	boss._advance_patrol(STEP, 84, 2220)
	assert(boss.body.global_position == Vector2(2214, 129))
	boss._breath_ticks = 1
	boss._advance_patrol(STEP, 85, 2090)
	assert(boss._mouth_open and boss.sprite.frame >= 2)
	var feet_ticks := boss._feet_ticks
	boss._jump_ticks = 2
	boss._advance_patrol(STEP, 88, 2090)
	assert(boss.body.global_position == Vector2(2214, 128))
	assert(boss._feet_ticks == feet_ticks)
	assert(boss._jump_ticks == 1)


func _check_contact(boss: Bowser, mario: Mario) -> void:
	boss.body.global_position = Vector2(2218, 125)
	boss._direction = Bowser.FACE_LEFT
	boss._update_pose()
	var front := boss.get_node("Body/PlayerContact/CollisionShape2D") as CollisionShape2D
	var rear := boss.get_node("Body/RearContact/CollisionShape2D") as CollisionShape2D
	assert(CONTACT.bounds(front) == Rect2(2218, 127, 16, 19))
	assert(CONTACT.bounds(rear) == Rect2(2234, 135, 16, 19))
	mario.body.global_position = Vector2(2243, 134)
	assert(not boss._touches_player_now(mario), "The empty space above the rear must stay clear.")
	mario.body.position.y += 1.0
	assert(boss._touches_player_now(mario), "An exactly touching edge must count.")
	boss._direction = Bowser.FACE_RIGHT
	boss._update_pose()
	assert(CONTACT.bounds(rear) == Rect2(2202, 135, 16, 19))
	assert(not boss._touches_player_now(mario))


func _check_damage(boss: Bowser, mario: Mario) -> void:
	boss._direction = Bowser.FACE_LEFT
	boss._update_pose()
	# Contact each half independently from above while descending.
	for x in [2226.0, 2243.0]:
		mario.form_presentation.cancel()
		mario.damage.clear()
		mario.form_controller.configure(mario, mario.super_form)
		mario.body.global_position = Vector2(x, 138)
		mario.body.velocity.y = 60.0
		while not CONTACT.is_check_tick():
			await get_tree().physics_frame
		boss._check_normal_player_contact(mario)
		assert(mario.form_presentation.active)
		assert(mario.body.velocity.y != BaseEnemy.STOMP_REBOUND)


func _check_fireballs(level: BaseLevel, boss: Bowser, mario: Mario) -> void:
	var origin := Vector2(2222, 92)
	boss.body.global_position = origin
	boss._vertical.position_fraction = 96
	boss._direction = Bowser.FACE_LEFT
	boss._update_pose()
	var bowser_art := boss.sprite.texture
	var score := GameHandler.player_status.score
	var view := Rect2(2022, 0, 256, 240)
	for hit_index in range(5):
		var offset := Vector2(6, 10) if hit_index % 2 == 0 else Vector2(22, 18)
		_hit_with_fireball(level, mario, origin + offset, view)
		assert(boss.hit_points == 4 - hit_index)
		assert(boss.is_defeated() == (hit_index == 4))
		assert(boss.sprite.texture == bowser_art)
		assert(GameHandler.player_status.score == score)

	assert(boss.body.global_position == Vector2(2222, 90))
	assert(boss.sprite.global_position == origin + Vector2(0, 1))
	assert(not boss.can_contact_fireball())
	var popup := level.world_objects.get_node("ScorePopup") as Sprite2D
	assert(popup.region_rect.position == Vector2(16, 24))
	assert(popup.global_position == Vector2(2230, 88) and not popup.visible)

	var hit_tick := Engine.get_physics_frames()
	var score_ticks: Array[int] = []
	var record_score := func(key: StringName, _value: Variant) -> void:
		if key == &"score":
			score_ticks.append(Engine.get_physics_frames() - hit_tick)
	GameHandler.session_value_changed.connect(record_score)
	boss._advance_defeat(STEP)
	assert(boss.sprite.texture == bowser_art)
	var trace_y := [88, 87, 85, 84, 83]
	for y in trace_y:
		await get_tree().physics_frame
		boss._advance_defeat(STEP)
		assert(boss.body.global_position == Vector2(2222, y))
		assert(boss.sprite.texture.resource_path.ends_with("/castle/enemies/goomba.png"))
		assert(boss.sprite.flip_v and boss.sprite.frame == 0)
		if y == trace_y[0]:
			assert(boss.sprite.global_position == Vector2(2222, 103))
	await get_tree().physics_frame
	GameHandler.session_value_changed.disconnect(record_score)
	assert(score_ticks == [5])
	assert(GameHandler.player_status.score == score + 5000)

	var seam_boss := BOWSER.instantiate() as Bowser
	level.world_objects.add_child(seam_boss)
	seam_boss.set_physics_process(false)
	seam_boss.body.global_position = origin
	seam_boss._direction = Bowser.FACE_LEFT
	seam_boss._update_pose()
	for expected_hp in [3, 1, 0]:
		_hit_with_fireball(level, mario, origin + Vector2(8, 10), view)
		assert(seam_boss.hit_points == expected_hp)
	assert(seam_boss.is_defeated())
	for child in level.world_objects.get_children():
		if child is Sprite2D and child != popup:
			assert(child.global_position == origin + Vector2(24, 4))
	# Repeated hits on retired boxes cannot wrap health or award twice.
	_hit_with_fireball(level, mario, origin + Vector2(8, 10), view, false)
	assert(seam_boss.hit_points == 0)


func _hit_with_fireball(
	level: BaseLevel, mario: Mario, origin: Vector2, view: Rect2, bursts := true
) -> void:
	var shot := SHOT.instantiate() as Fireball
	level.world_objects.add_child(shot)
	shot._area = level.active_area
	shot._spawn_registry = level.spawn_registry
	shot._shooter = mario
	shot.global_position = origin
	shot._hit_enemies(view)
	assert(shot.burst_tick == (0 if bursts else -1))
	shot.free()

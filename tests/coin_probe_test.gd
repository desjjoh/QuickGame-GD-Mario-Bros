extends Node
const COIN := preload("res://scenes/entities/coin/coin.tscn")
var mario: Mario


func ticks(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
		await get_tree().process_frame


func sample() -> void:
	mario.terrain.collect_coins(
		mario,
		not mario.form_controller.current_form.can_crouch or mario.form_controller.is_crouched
	)


func make_coin(at: Vector2) -> WorldCoin:
	var coin := COIN.instantiate() as WorldCoin
	coin.position = at
	add_child(coin)
	return coin


func _ready() -> void:
	mario = load("res://scenes/player/mario (small)/mario.tscn").instantiate() as Mario
	add_child(mario)
	mario.set_physics_process(false)
	ControllerHandler.set_physics_process(false)
	mario.body.global_position = Vector2(128, 208)
	var checked := 0
	for form in [MarioFormPresentation.SMALL, MarioFormPresentation.SUPER]:
		for crouched in [false, true]:
			if crouched and form == MarioFormPresentation.SMALL:
				continue
			mario.form_controller.configure(mario, form)
			mario.form_controller.set_crouched(crouched)
			var short_profile: bool = not form.can_crouch or crouched
			var head := Vector2(0, -14 if short_profile else -28)
			var side_y: float = -8 if short_profile else -24
			var positions: Array[Vector2] = [
				mario.body.global_position + head - Vector2(8, 8),
				mario.body.global_position + Vector2(-20, side_y - 8),
				mario.body.global_position + Vector2(4, side_y - 8),
				mario.body.global_position + Vector2(-20, 0),
				mario.body.global_position + Vector2(0, 0)
			]
			if not short_profile:
				positions.append(mario.body.global_position + Vector2(-20, -16))
				positions.append(mario.body.global_position + Vector2(4, -16))
			for position in positions:
				var coin := make_coin(position)
				await ticks(2)
				var before := GameHandler.player_status.coins
				sample()
				assert(coin.capture_area_state().get("state") == &"Collected")
				assert(GameHandler.player_status.coins == before + 1)
				sample()
				assert(GameHandler.player_status.coins == before + 1)
				coin.free()
				checked += 1
	# An upper coin must not collect from the short Small/crouched profile.
	for form in [MarioFormPresentation.SMALL, MarioFormPresentation.SUPER]:
		mario.form_controller.configure(mario, form)
		mario.form_controller.set_crouched(form.can_crouch)
		var coin := make_coin(Vector2(120, 172))
		await ticks(2)
		sample()
		assert(coin.capture_area_state().is_empty())
		coin.free()
	# Probe priority awards one coin per update, head before feet.
	mario.form_controller.configure(mario, MarioFormPresentation.SUPER)
	var upper := make_coin(Vector2(120, 172))
	var lower := make_coin(Vector2(120, 208))
	await ticks(2)
	sample()
	assert(
		(
			upper.capture_area_state().get("state") == &"Collected"
			and lower.capture_area_state().is_empty()
		)
	)
	await ticks(1)
	sample()
	assert(lower.capture_area_state().get("state") == &"Collected")
	upper.free()
	lower.free()
	# Preserve consumed-state persistence and forbid suspended/dead/pipe pickups.
	var blocked := make_coin(Vector2(120, 172))
	await ticks(2)
	blocked.set_gameplay_suspended(true)
	sample()
	assert(blocked.capture_area_state().is_empty())
	blocked.set_gameplay_suspended(false)
	mario.is_dead = true
	await ticks(1)
	sample()
	assert(blocked.capture_area_state().is_empty())
	mario.is_dead = false
	mario.body.collision_mask = 0
	await ticks(1)
	sample()
	assert(blocked.capture_area_state().is_empty())
	mario.body.collision_mask = 1
	GameHandler.set_coins(99)
	var lives := GameHandler.player_status.lives
	var score := GameHandler.player_status.score
	await ticks(1)
	sample()
	assert(GameHandler.player_status.coins == 0 and GameHandler.player_status.lives == lives + 1)
	assert(GameHandler.player_status.score == score + 200)
	var restored := COIN.instantiate() as WorldCoin
	restored.restore_area_state(blocked.capture_area_state())
	restored.position = blocked.position
	add_child(restored)
	blocked.free()
	await ticks(2)
	sample()
	assert(
		(
			restored.capture_area_state().get("state") == &"Collected"
			and GameHandler.player_status.coins == 0
		)
	)
	restored.free()
	mario.free()
	print(
		"PASS: ",
		checked,
		" form-aware head/side/foot contacts, short-profile misses, one-coin priority, suspension/pipe gates, persistence and 100-coin reward."
	)
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

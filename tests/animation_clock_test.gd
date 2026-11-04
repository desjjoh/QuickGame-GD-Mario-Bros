extends Node

func expected_texture(phase: int) -> String:
	return ["question-block.png","question-block-2.png","question-block-3.png","question-block-2.png"][phase]

func check_pair(block: BaseBlock, coin: AnimatedSprite2D, clock: CosmeticAnimationClock, cycle: CosmeticAnimationCycle) -> void:
	var phase := cycle.phase_at(clock.tick_count)
	assert(coin.frame == phase)
	assert(block.sprite.texture.resource_path.ends_with(expected_texture(phase)))
	assert(not block.animation_player.is_playing() and not coin.is_playing())

func _ready() -> void:
	var clock := GameHandler.animation_clock
	var cycle := load("res://scenes/components/presentation/palette_pulse.tres") as CosmeticAnimationCycle
	assert(cycle.total_ticks() == 48)
	for sample in [[0,0],[23,0],[24,1],[31,1],[32,2],[39,2],[40,3],[47,3],[48,0]]:
		assert(cycle.phase_at(sample[0]) == sample[1])
	clock.set_physics_process(false)
	var hud := load("res://scenes/ui/hud/hud.tscn").instantiate() as Control
	add_child(hud)
	var coin := hud.get_node("Coin") as AnimatedSprite2D
	var first := load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
	add_child(first)
	var later: BaseBlock
	for tick in range(96):
		if tick == 29:
			later = load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
			later.visual_theme = load("res://assets/themes/underground.tres")
			add_child(later)
		if tick == 35: first.set_gameplay_suspended(true)
		check_pair(first,coin,clock,cycle)
		if later != null:
			check_pair(later,coin,clock,cycle)
			assert(later.sprite.texture.resource_path.contains("/palettes/underground/"))
		clock._physics_process(1.0/60.0)
	first.set_gameplay_suspended(false)
	assert(first.receive_hit(EntityHit.new(null,&"bonk",Vector2.UP)))
	var used_texture := first.sprite.texture
	for tick in range(60): clock._physics_process(1.0/60.0)
	assert(first.sprite.texture == used_texture, "Shared phases must not overwrite bounce presentation.")
	for frame in range(30): first.state_machine.process_physics(1.0/60.0)
	assert(first.state_machine.current_state.name == &"Inactive")
	for tick in range(60): clock._physics_process(1.0/60.0)
	assert(first.sprite.texture == used_texture)
	later.shutdown()
	var frozen := later.sprite.texture
	for tick in range(60): clock._physics_process(1.0/60.0)
	assert(later.sprite.texture == frozen)
	first.free()
	later.free()
	hud.free()
	assert(clock._groups.is_empty())
	clock.set_physics_process(true)
	# GameHandler session reset and real area/level recreation must not reset phase.
	var game := load("res://scenes/main/game.tscn").instantiate() as Node
	game.start_with_title = false
	game.transitions_enabled = false
	add_child(game)
	var tick_before := clock.tick_count
	GameHandler.clear_session()
	assert(clock.tick_count == tick_before)
	assert(GameHandler.current_level.request_area_transfer(&"lower"))
	await get_tree().process_frame
	assert(clock.tick_count >= tick_before)
	assert(GameHandler.load_level(game.initial_level))
	assert(clock.tick_count >= tick_before)
	var target_coin := game.get_node("UI/HUD/Coin") as AnimatedSprite2D
	assert(target_coin.frame == cycle.phase_at(clock.tick_count))
	if DisplayServer.get_name() != "headless":
		while cycle.phase_at(clock.tick_count) != 2:
			await RenderingServer.frame_post_draw
		var late_block := load("res://scenes/entities/blocks/question/question_block.tscn").instantiate() as BaseBlock
		late_block.position = Vector2(128,64)
		GameHandler.current_level.world_objects.add_child(late_block)
		check_pair(late_block,target_coin,clock,cycle)
		for frame in range(60):
			await RenderingServer.frame_post_draw
			check_pair(late_block,target_coin,clock,cycle)
	game.free()
	await get_tree().process_frame
	assert(clock._groups.is_empty())
	print("PASS: shared 48-tick phases, late/themed joins, cosmetic suspension, bounce/used ownership, shutdown/unsubscribe, and clock continuity through area/level/session changes.")
	get_tree().quit()

extends Node

const GOOMBA := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
const KOOPA := preload("res://scenes/entities/enemies/koopa/green_koopa.tscn")
const MUSHROOM := preload("res://scenes/entities/powerups/one_up_mushroom.tscn")


func ticks(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func place(level: BaseLevel, actor: BaseEntity) -> void:
	level.world_objects.add_child(actor)
	actor.set_physics_process(false)
	(actor.get("body") as CharacterBody2D).global_position = Vector2(200, 104)


func enemy(level: BaseLevel, registered := true) -> BaseEnemy:
	var actor := GOOMBA.instantiate() as BaseEnemy
	if registered:
		assert(level.try_claim_spawn_slot(&"enemy", actor))
	place(level, actor)
	return actor


func mushroom(level: BaseLevel, registered := true, emerging := false) -> Mushroom:
	var actor := MUSHROOM.instantiate() as Mushroom
	if emerging:
		actor.begin_emergence()
	if registered:
		assert(level.try_claim_spawn_slot(&"power_up", actor))
	place(level, actor)
	return actor


func _ready() -> void:
	for wrapped in [false, true]:
		for breaking in [false, true]:
			for scenario in range(12):
				await check_case(wrapped, breaking, scenario)
	print("block_receiver_order_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())


func check_case(wrapped: bool, breaking: bool, scenario: int) -> void:
	var container: Node = CanvasLayer.new() if wrapped else Node2D.new()
	add_child(container)
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.player_start_configuration = load(
		(
			"res://assets/player/forms/super.tres"
			if breaking
			else "res://assets/player/forms/small.tres"
		)
	)
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	container.add_child(level)
	level.set_physics_process(false)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.body.global_position = Vector2(40, 100)
	var actors: Array[BaseEntity] = []
	var expected: BaseEntity
	match scenario:
		0:  # Claim slots before adding actors in reverse tree order.
			var low := KOOPA.instantiate() as BaseEnemy
			var high := GOOMBA.instantiate() as BaseEnemy
			assert(level.try_claim_spawn_slot(&"enemy", low))
			assert(level.try_claim_spawn_slot(&"enemy", high))
			place(level, high)
			place(level, low)
			actors.assign([high, low])
			expected = low
		1:  # A newly reused low slot precedes an older surviving high slot.
			var removed := enemy(level)
			var high := enemy(level)
			removed.free()
			var reused := enemy(level)
			assert(level.spawn_registry.get_slot(&"enemy", reused) == 0)
			actors.assign([high, reused])
			expected = reused
		2:  # Category precedes tree order: mushroom was placed first.
			actors.assign([mushroom(level), enemy(level)])
			expected = actors[1]
		3:  # Rejected low slot falls through to another enemy before the mushroom.
			var low := enemy(level)
			low.set_gameplay_suspended(true)
			actors.assign([low, mushroom(level), enemy(level)])
			expected = actors[2]
		4:  # All enemies reject, so the mushroom receives the reaction.
			var low := enemy(level)
			low.set_activity_suspended(true)
			actors.assign([low, mushroom(level)])
			expected = actors[1]
		5:  # Registered actors precede unregistered actors in the same category.
			actors.assign([enemy(level, false), enemy(level)])
			expected = actors[1]
		6:  # Unregistered actors use tree order, independently of their names.
			var first := enemy(level, false)
			first.name = "ZFirst"
			var second := enemy(level, false)
			second.name = "ASecond"
			actors.assign([first, second])
			expected = first
		7:  # Even an unregistered enemy precedes a registered power-up.
			actors.assign([mushroom(level), enemy(level, false)])
			expected = actors[1]
		8:  # Rejected emerging power-up must not swallow a later available receiver.
			actors.assign([mushroom(level, true, true), mushroom(level, false)])
			expected = actors[1]
		9:  # A lower slot outside the query does not reserve the reaction.
			var outside := enemy(level)
			outside.body.global_position.x = 120
			actors.assign([outside, mushroom(level)])
			expected = actors[1]
		10:  # The tenth enemy slot still precedes power-up slot0.
			for slot in range(10):
				var actor := enemy(level)
				if slot < 9:
					actor.body.global_position.x = 120
				else:
					expected = actor
				actors.append(actor)
			actors.append(mushroom(level))
			assert(not level.has_spawn_capacity(&"enemy"))
		11:  # No acceptance means no entity reaction or delayed reward.
			var actor := enemy(level)
			actor.set_gameplay_suspended(true)
			var item := mushroom(level)
			item._removing = true
			actors.assign([actor, item])
	var block := (
		load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate() as BaseBlock
	)
	block.position = Vector2(192, 112)
	level.world_objects.add_child(block)
	await ticks(2)
	if scenario == 4:
		actors[0].set_activity_suspended(true)
	var before: Array[Dictionary] = []
	for actor in actors:
		before.append(
			{"state": actor.state_machine.current_state, "velocity": actor.get("body").velocity}
		)
	var score := GameHandler.player_status.score
	assert(block.receive_hit(EntityHit.new(level.player, &"bonk", Vector2.UP)))
	for index in range(actors.size()):
		var actor := actors[index]
		if actor == expected:
			if actor is BaseEnemy:
				assert(
					actor.state_machine.current_state.name in [&"KnockedOut", &"ShellStunned"],
					"Winner scenario %d" % scenario
				)
			else:
				assert(actor.get("body").velocity == Vector2(60, -180))
		else:
			assert(
				actor.state_machine.current_state == before[index].state,
				"Extra reaction scenario %d" % scenario
			)
			assert(actor.get("body").velocity == before[index].velocity)
	var brick_points := 50 if breaking else 0
	assert(GameHandler.player_status.score == score + brick_points)
	await ticks(6)
	assert(
		(
			GameHandler.player_status.score
			== score + brick_points + (100 if expected is BaseEnemy else 0)
		)
	)
	container.free()
	await get_tree().process_frame

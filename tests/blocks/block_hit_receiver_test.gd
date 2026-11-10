extends Node

const RECEIVER := preload("res://scenes/components/interactions/block_hit_receiver.tscn")


func _ready() -> void:
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.body.global_position = Vector2(24, 100)
	var hit := EntityHit.new(level.player, &"block_bump", Vector2.UP)
	var receiver := RECEIVER.instantiate() as BlockHitReceiver
	add_child(receiver)
	assert(not receiver.receive_hit(hit) and not receiver.receive_hit(null))
	var handler_owner := Node.new()
	receiver.hit_handler = handler_owner.is_inside_tree.unbind(1)
	handler_owner.free()
	assert(not receiver.receive_hit(hit))
	receiver.free()
	# Enemy acknowledgement comes directly from the existing entity hit contract.
	var goomba := (
		load("res://scenes/entities/enemies/goomba/goomba.tscn").instantiate() as BaseEnemy
	)
	level.world_objects.add_child(goomba)
	receiver = goomba.get_node("Body/BlockHitReceiver") as BlockHitReceiver
	goomba._handling_hit = true
	assert(not receiver.receive_hit(hit))
	goomba._handling_hit = false
	goomba.set_gameplay_suspended(true)
	assert(not receiver.receive_hit(hit) and not goomba._defeated)
	goomba.set_gameplay_suspended(false)
	goomba.set_activity_suspended(true)
	assert(not receiver.receive_hit(hit) and not goomba._defeated)
	goomba.set_activity_suspended(false)
	assert(receiver.receive_hit(hit))
	assert(goomba._defeated and goomba.state_machine.current_state.name == &"KnockedOut")
	assert(not receiver.receive_hit(hit))
	var koopa := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	koopa.position = Vector2(144, 192)
	level.world_objects.add_child(koopa)
	receiver = koopa.get_node("Body/BlockHitReceiver") as BlockHitReceiver
	var position := koopa.body.global_position
	assert(receiver.receive_hit(hit))
	assert(koopa.state_machine.current_state.name == &"ShellStunned" and not koopa._defeated)
	assert(koopa.body.global_position.is_equal_approx(position + Vector2(1, -5)))
	assert(koopa.body.velocity == Vector2(60, -165.703125))
	assert(receiver.receive_hit(hit))  # A recoverable repeat is still accepted.
	assert(koopa.body.global_position.is_equal_approx(position + Vector2(2, -10)))
	koopa.shutdown()
	assert(not receiver.receive_hit(hit))
	# Both mushroom types preserve their launch and all existing rejection guards.
	for path in [
		"res://scenes/entities/powerups/one_up_mushroom.tscn",
		"res://scenes/entities/powerups/super_mushroom.tscn"
	]:
		var mushroom := load(path).instantiate() as Mushroom
		level.world_objects.add_child(mushroom)
		mushroom.body.global_position = Vector2(144, 128)
		receiver = mushroom.get_node("Body/BlockHitReceiver") as BlockHitReceiver
		assert(not receiver.receive_hit(null))
		assert(receiver.receive_hit(hit))
		assert(mushroom.body.velocity == Vector2(60, -180))
		level.player.body.global_position.x = 240
		assert(receiver.receive_hit(hit))
		assert(mushroom.body.velocity == Vector2(-60, -180))
		assert(receiver.receive_hit(EntityHit.new(null, &"block_bump", Vector2.UP)))
		assert(mushroom.body.velocity == Vector2(60, -180))
		mushroom.set_gameplay_suspended(true)
		assert(not receiver.receive_hit(hit))
		mushroom.set_gameplay_suspended(false)
		mushroom.set_activity_suspended(true)
		assert(not receiver.receive_hit(hit))
		mushroom.set_activity_suspended(false)
		mushroom._removing = true
		assert(not receiver.receive_hit(hit))
		mushroom._removing = false
		assert(mushroom.body.velocity == Vector2(60, -180))
		mushroom.queue_free()
		assert(not receiver.receive_hit(hit))
		var emerging := load(path).instantiate() as Mushroom
		emerging.begin_emergence()
		level.world_objects.add_child(emerging)
		receiver = emerging.get_node("Body/BlockHitReceiver") as BlockHitReceiver
		assert(not receiver.receive_hit(hit) and emerging.body.velocity == Vector2.ZERO)
		emerging.free()
		var retired := load(path).instantiate() as Mushroom
		level.world_objects.add_child(retired)
		retired.shutdown()
		receiver = retired.get_node("Body/BlockHitReceiver") as BlockHitReceiver
		assert(not receiver.receive_hit(hit))
		retired.free()
		level.player.body.global_position.x = 24
	level.free()
	await get_tree().process_frame
	print("block_hit_receiver_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

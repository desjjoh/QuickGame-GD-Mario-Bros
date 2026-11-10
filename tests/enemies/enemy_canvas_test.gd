extends Node


func ticks(count: int) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	ControllerHandler.set_physics_process(false)
	for wrapped in [false, true]:
		for species in ["goomba", "koopa/green_koopa"]:
			var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
			level.player_start_configuration = load("res://assets/player/forms/super.tres")
			level.entity_layout.clear()
			level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
			var container: Node = CanvasLayer.new() if wrapped else Node2D.new()
			add_child(container)
			container.add_child(level)
			var player := level.player
			player.set_physics_process(false)
			var path := (
				"res://scenes/entities/enemies/goomba/goomba.tscn"
				if species == "goomba"
				else "res://scenes/entities/enemies/koopa/green_koopa.tscn"
			)
			var enemy := load(path).instantiate() as BaseEnemy
			enemy.position = Vector2(192, 96)
			level.world_objects.add_child(enemy)
			enemy.set_physics_process(false)
			enemy.body.global_position = Vector2(200, 104)
			player.body.global_position = Vector2(200, 108)
			await ticks(2)
			assert(
				enemy._player_contact_area.overlaps_area(player.enemy_hurtbox),
				"Super hurtbox overlap must work on either canvas"
			)
			player.body.global_position = Vector2(40, 100)
			var block := (
				load("res://scenes/entities/blocks/brick/brick_block.tscn").instantiate()
				as BaseBlock
			)
			block.position = Vector2(192, 112)
			level.world_objects.add_child(block)
			await ticks(2)
			assert(block.receive_hit(EntityHit.new(player, &"bonk", Vector2.UP)))
			if species == "goomba":
				assert(enemy._defeated, "Block shape query must reach Goomba")
			else:
				assert(
					enemy.state_machine.current_state.name == &"ShellStunned",
					"Block shape query must reach Koopa"
				)
			container.free()
	ControllerHandler.set_physics_process(true)
	print("enemy_canvas_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

extends Node

const REGISTRY := preload("res://scenes/levels/base/level_spawn_registry.gd")
var registry: LevelSpawnRegistry


func claim(category: StringName, expected_slot: int) -> Node2D:
	var actor := Node2D.new()
	assert(registry.try_claim(category, actor))
	# Identity is assigned at claim time, before the actor enters the tree.
	assert(registry.get_slot(category, actor) == expected_slot)
	add_child(actor)
	return actor


func _ready() -> void:
	registry = REGISTRY.new()
	add_child(registry)
	assert(LevelSpawnRegistry.SPAWN_LIMITS[&"enemy"] == 10)
	var enemies: Array[Node2D] = []
	for slot in range(10):
		enemies.append(claim(&"enemy", slot))
	assert(not registry.has_capacity(&"enemy"))
	var rejected := Node2D.new()
	assert(not registry.try_claim(&"enemy", rejected))
	assert(registry.get_slot(&"enemy", rejected) == -1)
	rejected.free()
	# Category-local slots and limits are independent.
	var power_up := claim(&"power_up", 0)
	assert(not registry.has_capacity(&"power_up"))
	assert(registry.get_slot(&"enemy", power_up) == -1)
	assert(registry.get_slot(&"power_up", enemies[0]) == -1)
	claim(&"unlimited", -1)
	claim(&"unlimited", -1)
	assert(registry.has_capacity(&"unlimited"))
	assert(not registry._live_spawns.has(&"unlimited"))
	assert(not registry._spawn_slots.has(&"unlimited"))
	# Free two holes out of order: allocate the lowest, never renumber survivors.
	enemies[3].free()
	enemies[1].free()
	assert(registry.has_capacity(&"enemy"))
	var reused_one := claim(&"enemy", 1)
	var reused_three := claim(&"enemy", 3)
	for slot in [0, 2, 4, 5, 6, 7, 8, 9]:
		assert(registry.get_slot(&"enemy", enemies[slot]) == slot)
	assert(not registry.has_capacity(&"enemy"))
	# Make slot0 the newest actor. Replacement must still remove oldest slot2.
	enemies[0].free()
	var newest_zero := claim(&"enemy", 0)
	var replacement := Node2D.new()
	assert(registry.try_claim(&"enemy", replacement, true))
	assert(enemies[2].is_queued_for_deletion() and not enemies[2].visible)
	assert(not newest_zero.is_queued_for_deletion())
	assert(registry.get_slot(&"enemy", enemies[2]) == -1)
	assert(registry.get_slot(&"enemy", replacement) == 2)
	add_child(replacement)
	# Replacement reuses the slot immediately; the old exit cannot release it.
	var new_power_up := Node2D.new()
	assert(registry.try_claim(&"power_up", new_power_up, true))
	assert(power_up.is_queued_for_deletion() and not power_up.visible)
	assert(registry.get_slot(&"power_up", power_up) == -1)
	assert(registry.get_slot(&"power_up", new_power_up) == 0)
	add_child(new_power_up)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(registry.get_slot(&"enemy", replacement) == 2)
	assert(registry.get_slot(&"power_up", new_power_up) == 0)
	assert(not registry.has_capacity(&"enemy") and not registry.has_capacity(&"power_up"))
	assert(registry.get_slot(&"enemy", reused_one) == 1)
	assert(registry.get_slot(&"enemy", reused_three) == 3)
	# Leaving the tree releases identity even if the actor remains allocated.
	remove_child(replacement)
	assert(registry.get_slot(&"enemy", replacement) == -1)
	assert(registry.has_capacity(&"enemy"))
	replacement.free()
	claim(&"enemy", 2)
	var fresh := REGISTRY.new()
	assert(fresh.has_capacity(&"enemy") and fresh.get_slot(&"enemy", newest_zero) == -1)
	fresh.free()
	for child in get_children():
		if child != registry:
			child.free()
	assert(registry._live_spawns[&"enemy"].is_empty())
	assert(registry._spawn_slots[&"enemy"].is_empty())
	assert(registry._spawn_slots[&"power_up"].is_empty())
	registry.free()
	print("spawn_registry_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

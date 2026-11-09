class_name LevelSpawnRegistry
extends Node
## Tracks level-local capacity; sources retain activation and replacement policy.

const SPAWN_LIMITS := {&"power_up": 1, &"enemy": 10}

var _live_spawns: Dictionary[StringName, Array] = {}
var _spawn_slots: Dictionary[StringName, Dictionary] = {}


func has_capacity(category: StringName) -> bool:
	return (
		not SPAWN_LIMITS.has(category)
		or _live_spawns.get(category, []).size() < SPAWN_LIMITS[category]
	)


## Category-local identity, independent of spawn age. Untracked actors return -1.
func get_slot(category: StringName, actor: Node) -> int:
	return _spawn_slots.get(category, {}).get(actor, -1)


## Claim immediately before adding a new actor to the tree.
func try_claim(category: StringName, actor: Node, replace_oldest := false) -> bool:
	if SPAWN_LIMITS.has(category):
		var live: Array = _live_spawns.get_or_add(category, [])
		var slots: Dictionary = _spawn_slots.get_or_add(category, {})
		if live.size() >= SPAWN_LIMITS[category]:
			if not replace_oldest:
				return false
			var previous: Node = live.pop_front()
			slots.erase(previous)
			previous.queue_free()
			if previous is CanvasItem:
				previous.hide()
		live.append(actor)
		# Keep the age-ordered list intact: replacement still removes the oldest.
		for slot in range(SPAWN_LIMITS[category]):
			if not slots.values().has(slot):
				slots[actor] = slot
				break
		actor.tree_exited.connect(_release_spawn_slot.bind(category, actor), CONNECT_ONE_SHOT)
	return true


func _release_spawn_slot(category: StringName, actor: Node) -> void:
	_live_spawns[category].erase(actor)
	_spawn_slots[category].erase(actor)

class_name LevelSpawnRegistry
extends Node
## Tracks level-local capacity; sources retain activation and replacement policy.

const DEFAULT_ENEMY_LIMIT := 5

var enemy_limit: int = DEFAULT_ENEMY_LIMIT

var _live_spawns: Dictionary[StringName, Array] = {}
var _spawn_slots: Dictionary[StringName, Dictionary] = {}


func has_capacity(category: StringName) -> bool:
	var limit := _get_limit(category)
	return limit < 0 or _live_spawns.get(category, []).size() < limit


## Category-local identity, independent of spawn age. Untracked actors return -1.
func get_slot(category: StringName, actor: Node) -> int:
	return _spawn_slots.get(category, {}).get(actor, -1)


## Claim immediately before adding a new actor to the tree.
func try_claim(category: StringName, actor: Node, replace_oldest := false) -> bool:
	var limit := _get_limit(category)
	if limit == 0:
		return false
	if limit > 0:
		var live: Array = _live_spawns.get_or_add(category, [])
		var slots: Dictionary = _spawn_slots.get_or_add(category, {})
		if live.size() >= limit:
			if not replace_oldest:
				return false
			var previous: Node = live.pop_front()
			slots.erase(previous)
			previous.queue_free()
			if previous is CanvasItem:
				previous.hide()
		live.append(actor)
		# Keep the age-ordered list intact: replacement still removes the oldest.
		for slot in range(limit):
			if not slots.values().has(slot):
				slots[actor] = slot
				break
		actor.tree_exited.connect(_release_spawn_slot.bind(category, actor), CONNECT_ONE_SHOT)
	return true


func _get_limit(category: StringName) -> int:
	match category:
		&"enemy":
			return maxi(enemy_limit, 0)
		&"power_up":
			return 1
		_:
			return -1


func _release_spawn_slot(category: StringName, actor: Node) -> void:
	_live_spawns[category].erase(actor)
	_spawn_slots[category].erase(actor)

class_name CosmeticAnimationClock
extends Node
## One clock; clients are notified only when their shared cycle changes phase.

var tick_count: int = 0
var _groups: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	process_physics_priority = -90


func subscribe(client: Node, cycle: CosmeticAnimationCycle, offset: int = 0) -> void:
	unsubscribe(client)
	if cycle == null or cycle.total_ticks() <= 0:
		push_error("Synchronized animation requires positive phase durations.")
		return
	var normalized := posmod(offset, cycle.total_ticks())
	var key := "%s:%s" % [cycle.get_instance_id(), normalized]
	if not _groups.has(key):
		_groups[key] = {
			"cycle": cycle,
			"offset": normalized,
			"phase": cycle.phase_at(tick_count + normalized),
			"clients": []
		}
	var group := _groups[key]
	group.clients.append(client)
	client.apply_phase(group.phase)


func unsubscribe(client: Node) -> void:
	for key in _groups.keys():
		var group := _groups[key]
		group.clients.erase(client)
		if group.clients.is_empty():
			_groups.erase(key)


func _physics_process(_delta: float) -> void:
	tick_count += 1
	for key in _groups.keys():
		var group: Dictionary = _groups.get(key, {})
		if group.is_empty():
			continue
		var cycle := group.cycle as CosmeticAnimationCycle
		var phase := cycle.phase_at(tick_count + int(group.offset))
		if phase == group.phase:
			continue
		group.phase = phase
		# Callbacks may unsubscribe or remove other clients.
		for client: Node in group.clients.duplicate():
			if is_instance_valid(client) and client.is_inside_tree() and group.clients.has(client):
				client.apply_phase(phase)

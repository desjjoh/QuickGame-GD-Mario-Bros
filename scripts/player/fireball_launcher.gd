extends RefCounted
## The next slot advances only after a successful shot.

const FIREBALL := preload("res://scenes/entities/projectiles/fireball.tscn")

var _slots: Dictionary[int, WeakRef] = {}
var _next_slot := 0


func try_launch(player: Mario) -> Fireball:
	var limit := player.max_fireballs
	if limit <= 0:
		return null
	for slot: int in _slots.keys():
		if _slots[slot].get_ref() == null:
			_slots.erase(slot)
	var slot := _next_slot % limit
	if _slots.size() >= limit or _slots.has(slot):
		return null
	var level := BaseLevel.containing(player)
	if level == null or not is_instance_valid(level.active_area):
		return null
	var area := level.active_area
	var projectile := FIREBALL.instantiate() as Fireball
	area.get_node("WorldObjects").add_child(projectile)
	_slots[slot] = weakref(projectile)
	_next_slot = (slot + 1) % limit
	player.play_sound_effect(SoundHandler.get_sound(&"fireball"))
	projectile.launch(player, area)
	return projectile

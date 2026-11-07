extends "res://scripts/states/enemies/koopa_shell_idle_state.gd"

const CHAIN_POINTS := [500, 800, 1000, 2000, 4000, 5000, 8000]
var _touching: Dictionary[int, bool] = {}


func enter() -> void:
	walk_speed = 180.0
	super.enter()
	_touching.clear()
	(entity as BaseEnemy).body.velocity.x = walk_speed * _direction


func process_physics(delta: float) -> BaseState:
	super.process_physics(delta)
	var enemy := entity as BaseEnemy
	var present: Dictionary[int, bool] = {}
	for area: Area2D in enemy._enemy_contact_area.get_overlapping_areas():
		var other := area.get_parent().get_parent() as BaseEnemy
		if other == null or other == enemy:
			continue
		present[other.get_instance_id()] = true
		enemy._on_enemy_contact(area)
		if enemy._defeated or enemy.is_shutdown:
			return null
	for id: int in _touching.keys():
		if not present.has(id):
			_touching.erase(id)
	return null


func _turn_around() -> void:
	super._turn_around()
	entity.play_sound_effect(SoundHandler.get_sound(&"bump"))


func _on_enemy_contact(other: BaseEnemy) -> void:
	var enemy := entity as BaseEnemy
	if enemy._defeated or enemy.state_machine.current_state != self:
		return
	if _touching.has(other.get_instance_id()) or not other._blocks_enemy_contact():
		return
	_touching[other.get_instance_id()] = true
	var position := (
		other.sprite.global_position if other.sprite != null else other.body.global_position
	)
	var mutual := other.is_moving_shell()
	if not other.receive_hit(EntityHit.new(enemy, &"shell", Vector2(_direction, 0))):
		return
	if not other._defeated:
		return  # A surviving reaction is not a chain defeat.
	if mutual:
		var own_position := enemy.sprite.global_position
		if enemy.receive_hit(EntityHit.new(other, &"shell", Vector2(-_direction, 0))):
			enemy.award_score(1000, own_position)
	enemy.play_sound_effect(SoundHandler.get_sound(&"enemy_smack"))
	if enemy.shell_chain < CHAIN_POINTS.size():
		enemy.award_score(CHAIN_POINTS[enemy.shell_chain], position)
	else:
		enemy.award_extra_life(position)
	enemy.shell_chain += 1

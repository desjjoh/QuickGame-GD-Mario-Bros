class_name Fireball
extends Node2D
## Moves in integer pixels with the NES's separate position and speed fractions.

const BURST := preload("res://assets/items/fireworks.png")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
const TERRAIN_PROBE := preload("res://scenes/components/interactions/terrain_probe.gd")
const PROBE := Vector2(4, 6)
const SUBPIXEL := 256
const GRAVITY := 0x50
const FALL_CAP := 3 * SUBPIXEL
const PROJECTILE_BARRIER_LAYER := 1 << 11
const ENEMY_LEFT_EDGE_ALLOWANCE := 7.0

var bouncing := false
var burst_tick := -1
var vertical_speed: int:
	get:
		return _speed >> 8

var _shooter: Mario
var _area: BaseLevelArea
var _spawn_registry: LevelSpawnRegistry
var _launch_frame := -1
var _horizontal_step := 4
var _speed := 4 * SUBPIXEL
var _position_fraction := 0
var _probe := PhysicsPointQueryParameters2D.new()
var _barrier_probe := PhysicsRayQueryParameters2D.new()

@onready var sprite: Sprite2D = $Presentation/Sprite


func _ready() -> void:
	DRAW_ORDER.apply(sprite, DRAW_ORDER.FIREBALL)


func launch(shooter: Mario, area: BaseLevelArea) -> void:
	_shooter = shooter
	_area = area
	_spawn_registry = BaseLevel.containing(area).spawn_registry
	_horizontal_step = -4 if shooter.sprite.flip_h else 4
	_probe.collision_mask = shooter.body.collision_mask
	_probe.exclude = [shooter.body.get_rid()]
	_barrier_probe.collision_mask = PROJECTILE_BARRIER_LAYER
	_barrier_probe.hit_from_inside = true
	var feet := shooter.body.global_position
	var origin := feet.floor()
	# Godot's floor contact can leave the feet fractionally above the surface.
	if shooter.has_floor_support():
		origin.y = roundf(feet.y)
	global_position = origin - Vector2(4, 32)
	_launch_frame = Engine.get_physics_frames()
	advance()
	reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	if _launch_frame == Engine.get_physics_frames():
		return
	if not is_instance_valid(_shooter) or _shooter.is_shutdown or _shooter.is_dead:
		queue_free()
		return
	if _area.actors_suspended or _shooter.form_presentation.active:
		return
	advance()


func advance() -> void:
	if burst_tick >= 0:
		burst_tick += 1
		if burst_tick == 7:
			queue_free()
			sprite.hide()
		else:
			sprite.texture = BURST
			sprite.hframes = 3
			sprite.position = Vector2(-4, -4)
			sprite.frame = (burst_tick - 1) >> 1
		return
	var step := _position_fraction + _speed
	global_position += Vector2(_horizontal_step, step >> 8)
	_position_fraction = step & 0xff
	_speed += GRAVITY
	if _speed >= FALL_CAP and (_speed & 0xff) >= 0x80:
		_speed = FALL_CAP
	var view := _area.get_activity_region(false).grow(-_area.activation_buffer)
	var can_hit_terrain := global_position.y >= view.position.y + 24
	if can_hit_terrain and _hits_projectile_barrier():
		_begin_burst()
	elif can_hit_terrain and _touches_terrain():
		if vertical_speed < 0 or bouncing:
			_begin_burst()
		else:
			_speed = -3 * SUBPIXEL + (_speed & 0xff)
			global_position.y = floorf(global_position.y / 8.0) * 8.0
			bouncing = true
	else:
		bouncing = false
	if (
		global_position.x <= view.position.x
		or global_position.x + 8 >= view.end.x
		or global_position.y + 8 >= view.end.y
	):
		queue_free()
		sprite.hide()
	else:
		if burst_tick < 0 and GameHandler.animation_clock.tick_count % 2 == 0:
			_hit_enemies(view)
		sprite.frame = (GameHandler.animation_clock.tick_count >> 2) & 3


func _hit_enemies(view: Rect2) -> void:
	var shot_bounds := Rect2(global_position, Vector2(8, 8))
	var first_x := floorf(view.position.x)
	var last_x := floorf(view.end.x) - 1.0
	var targets: Array[BaseEnemy] = []
	for node in get_tree().get_nodes_in_group(BaseEnemy.FIREBALL_TARGETS):
		var enemy := node as BaseEnemy
		if not _area.is_ancestor_of(enemy) or not enemy.can_contact_fireball():
			continue
		var bounds := enemy.projectile_target_bounds()
		var origin_x := enemy.body.global_position.x - 8.0
		if (
			not bounds.has_area()
			or origin_x < first_x - ENEMY_LEFT_EDGE_ALLOWANCE
			or origin_x >= last_x + 1.0
			or bounds.position.y < view.position.y
			or bounds.end.y > view.end.y
		):
			continue
		# The NES clamps both inclusive endpoints, even if they land on the same pixel.
		var left := clampf(bounds.position.x, first_x, last_x)
		var right := clampf(bounds.end.x, first_x, last_x)
		bounds.position.x = left
		bounds.size.x = right - left
		if shot_bounds.intersects(bounds, true):
			targets.append(enemy)
	if targets.is_empty():
		return
	targets.sort_custom(
		func(a: BaseEnemy, b: BaseEnemy) -> bool:
			var a_slot := _spawn_registry.get_slot(&"enemy", a)
			var b_slot := _spawn_registry.get_slot(&"enemy", b)
			return a_slot > b_slot if a_slot != b_slot else b.is_greater_than(a)
	)
	# An eligible overlap consumes the shot even if the receiver resists the hit.
	burst_tick = 0
	for enemy in targets:
		if is_instance_valid(enemy) and enemy.can_contact_fireball():
			enemy.receive_hit(
				EntityHit.new(_shooter, &"fireball", Vector2(signf(_horizontal_step), 0))
			)


func _begin_burst() -> void:
	burst_tick = 0
	_shooter.play_sound_effect(SoundHandler.get_sound(&"bump"))


func _hits_projectile_barrier() -> bool:
	# Sweep the terrain probe's horizontal step at its updated height.
	_barrier_probe.to = global_position + PROBE
	_barrier_probe.from = _barrier_probe.to - Vector2(_horizontal_step, 0)
	var hit := get_world_2d().direct_space_state.intersect_ray(_barrier_probe)
	if hit.is_empty():
		return false
	global_position.x = (hit.position as Vector2).x - PROBE.x
	return true


func _touches_terrain() -> bool:
	_probe.position = global_position + PROBE + Vector2(0.01, 0.01)
	return TERRAIN_PROBE.hits_terrain(self, _probe)

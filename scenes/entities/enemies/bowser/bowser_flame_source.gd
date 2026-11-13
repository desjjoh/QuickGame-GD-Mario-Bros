@tool
class_name BowserFlameSource
extends Node2D
## One timer sequence for the approach stream and Bowser's mouth closures.

const FLAME := preload("res://scenes/entities/enemies/bowser/bowser_flame.tscn")
const DELAYS := [191, 64, 191, 191, 191, 64, 64, 191]
const HEIGHTS := [144, 128, 112, 144]
const GUIDE_COLOR := Color(1.0, 0.45, 0.25, 0.9)

@export_node_path("Node2D") var boss_spawner_path: NodePath

@onready var _area := get_parent().get_parent() as BaseLevelArea
var _level: BaseLevel

var _delay_index := 0
var _early_ticks := 0
var _early_started := false
var _boss_arrived := false
var _pending_breath := false
var _boss: Bowser
var _flame_voice: AudioStreamPlayer
var _flame_cue_pending := false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_notify_transform(true)
		queue_redraw()
		return
	_level = BaseLevel.containing(self)
	process_physics_priority = 105
	_flame_voice = AudioStreamPlayer.new()
	_flame_voice.name = "FlameCue"
	_flame_voice.bus = SoundHandler.NES_MIX_BUS
	_flame_voice.stream = SoundHandler.get_sound(&"bowser_flame")
	add_child(_flame_voice, false, Node.INTERNAL_MODE_BACK)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or _area == null:
		return
	var area_x := _area.to_local(global_position).x
	var height := float(ProjectSettings.get_setting("display/window/size/viewport_height", 240))
	var top := to_local(_area.to_global(Vector2(area_x, 0)))
	var bottom := to_local(_area.to_global(Vector2(area_x, height)))
	draw_dashed_line(top, bottom, GUIDE_COLOR, 1.0, 8.0)
	draw_string(
		ThemeDB.fallback_font,
		top + Vector2(4, 12),
		"Flame source: %s" % snappedf(area_x, 0.1),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		GUIDE_COLOR
	)


func _physics_process(_delta: float) -> void:
	if not _area.is_active or not _area.actors_initialized or _area.actors_suspended:
		return
	if _level.completion_in_progress:
		_flame_voice.stop()
		for child in get_children():
			child.hide()
			child.queue_free()
		set_physics_process(false)
		return
	if _flame_cue_pending:
		_flame_cue_pending = false
		_flame_voice.play()
	if _level.death_in_progress or _level.transition_in_progress:
		return
	var player := _level.player as Mario
	if is_instance_valid(player) and player.form_presentation.active:
		return
	if not _boss_arrived:
		var spawner := (
			get_node_or_null(boss_spawner_path) if not boss_spawner_path.is_empty() else null
		)
		_boss = spawner.get_node_or_null("Bowser") as Bowser if spawner != null else null
		if _boss != null:
			_boss_arrived = true
			_boss.flame_source = self
	_early_ticks = maxi(0, _early_ticks - 1)
	if _boss_arrived:
		if _pending_breath:
			if not is_instance_valid(_boss) or _boss.is_defeated():
				_pending_breath = false
			elif _early_ticks == 0 and _level.has_spawn_capacity(&"enemy"):
				_spawn(_boss.body.global_position + Vector2(-14, 8), _pick_height())
				_pending_breath = false
		return
	if not _early_started:
		var spawn_region := _area.get_enemy_spawn_region()
		_early_started = global_position.x < spawn_region.end.x
	if _early_started and _early_ticks == 0 and _level.has_spawn_capacity(&"enemy"):
		var view := _area.get_activity_region(false).grow(-_area.activation_buffer)
		var height := _pick_height()
		_spawn(Vector2(floorf(view.end.x) + 31, height), height)
		_early_ticks = _next_delay() + 32


func request_breath() -> int:
	_pending_breath = true
	return _next_delay()


func _next_delay() -> int:
	var delay: int = DELAYS[_delay_index]
	_delay_index = (_delay_index + 1) % DELAYS.size()
	return delay


func _pick_height() -> float:
	return _area.to_global(Vector2(0, HEIGHTS[randi_range(0, HEIGHTS.size() - 1)])).y


func _spawn(origin: Vector2, height: float) -> void:
	var flame := FLAME.instantiate() as BowserFlame
	if not _level.try_claim_spawn_slot(&"enemy", flame):
		flame.free()
		return
	flame.position = to_local(origin)
	flame.target_world_y = height
	add_child(flame)
	flame.reset_physics_interpolation()
	# The NES queues the cue at spawn and services it on the next update.
	_flame_cue_pending = true

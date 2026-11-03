class_name SynchronizedAnimation
extends Node
## Cosmetic-only phase sampling. No independent frame/physics processing.

@export var cycle: CosmeticAnimationCycle
@export var animation_player: AnimationPlayer
@export var animated_sprite: AnimatedSprite2D
@export var animation_name: StringName = &"default"
@export var phase_offset_ticks: int = 0
@export var start_enabled: bool = false

var enabled: bool = false
var _entity: BaseEntity

func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseEntity:
		ancestor = ancestor.get_parent()
	_entity = ancestor as BaseEntity
	set_enabled(start_enabled)

func set_enabled(value: bool) -> void:
	if enabled == value: return
	if value and (not is_inside_tree() or (is_instance_valid(_entity) and _entity.is_shutdown)):
		return
	enabled = value
	if not value:
		GameHandler.animation_clock.unsubscribe(self)
		return
	if animation_player != null:
		animation_player.play(animation_name)
		animation_player.pause()
	if animated_sprite != null:
		animated_sprite.play(animation_name)
		animated_sprite.pause()
	GameHandler.animation_clock.subscribe(self, cycle, phase_offset_ticks)

func apply_phase(phase: int) -> void:
	if not enabled: return
	if animation_player != null:
		animation_player.seek(cycle.phase_time(phase), true)
	if animated_sprite != null:
		animated_sprite.frame = phase

func _exit_tree() -> void:
	set_enabled(false)

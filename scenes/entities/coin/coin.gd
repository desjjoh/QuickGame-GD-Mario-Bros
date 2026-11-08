class_name WorldCoin
extends BaseEntity

signal collected(player: BasePlayer)

var _collected: bool = false

@onready var _pickup: Area2D = $Body/Pickup
@onready var _collected_state: BaseState = $StateMachine/Collected
@onready var _palette_animation: SynchronizedAnimation = $Presentation/PaletteAnimation


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if _collected:
		state_machine.initial_state = _collected_state
	state_machine.state_changed.connect(_on_state_changed)
	super()


func _on_state_changed(_previous: BaseState, next: BaseState) -> void:
	if next == null:
		return
	_collected = next == _collected_state
	sprite.visible = not _collected
	_palette_animation.set_enabled(not _collected)
	_pickup.set_deferred("collision_layer", 0 if _collected else 1)


## Called by a player's form-aware terrain probe, never the support-body overlap.
func collect(player: BasePlayer) -> bool:
	if _collected or is_shutdown or gameplay_suspended or activity_suspended:
		return false
	if (
		player == null
		or player.is_dead
		or player.is_shutdown
		or player.gameplay_suspended
		or player.activity_suspended
	):
		return false
	if not state_machine.change_state(_collected_state):
		return false
	GameHandler.award_coin()
	collected.emit(player)
	return true


func capture_area_state() -> Dictionary:
	return {"state": &"Collected"} if _collected else {}


func restore_area_state(data: Dictionary) -> void:
	_collected = StringName(data.get("state", &"")) == &"Collected"

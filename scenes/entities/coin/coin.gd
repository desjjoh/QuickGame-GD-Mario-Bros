extends BaseEntity

signal collected(player: BasePlayer)

var _collected: bool = false

@onready var _pickup: Area2D = $Pickup
@onready var _collected_state: BaseState = $StateMachine/Collected
@onready var _palette_animation: SynchronizedAnimation = $PaletteAnimation


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if _collected:
		state_machine.initial_state = _collected_state
	state_machine.state_changed.connect(_on_state_changed)
	_pickup.body_entered.connect(_on_body_entered)
	super()


func _on_state_changed(_previous: BaseState, next: BaseState) -> void:
	if next == null:
		return
	_collected = next == _collected_state
	sprite.visible = not _collected
	_palette_animation.set_enabled(not _collected)
	_pickup.set_deferred("monitoring", not _collected)


func _on_body_entered(body: Node2D) -> void:
	if _collected or is_shutdown or gameplay_suspended or activity_suspended:
		return
	var player := body.get_parent() as BasePlayer
	if (
		player == null
		or body != player.body
		or player.is_dead
		or player.is_shutdown
		or player.gameplay_suspended
	):
		return
	if state_machine.change_state(_collected_state):
		GameHandler.award_coin()
		collected.emit(player)


func capture_area_state() -> Dictionary:
	return {"state": &"Collected"} if _collected else {}


func restore_area_state(data: Dictionary) -> void:
	_collected = StringName(data.get("state", &"")) == &"Collected"

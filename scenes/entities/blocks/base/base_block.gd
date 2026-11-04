class_name BaseBlock
extends BaseEntity
## Solid grid-aligned block. Its origin is the tile's top-left corner.
## Concrete block scenes supply presentation and optional hit-reactive states.

@onready var body: StaticBody2D = $Body

@onready var bounce: BlockBounce = $Presentation/Bounce


func receive_hit(hit: EntityHit) -> bool:
	if (
		is_shutdown
		or gameplay_suspended
		or activity_suspended
		or not state_machine.current_state is EntityState
	):
		return false
	return (state_machine.current_state as EntityState).receive_hit(hit)


var _restored_state: StringName = &""
var _last_area_state: Dictionary = {}


func restore_area_state(data: Dictionary) -> void:
	_restored_state = StringName(data.get("state", &""))


func _ready() -> void:
	if _restored_state != &"":
		var saved := $StateMachine.get_node_or_null(NodePath(_restored_state)) as BaseState
		if saved != null:
			$StateMachine.initial_state = saved
	super()


func capture_area_state() -> Dictionary:
	if not is_instance_valid(state_machine) or state_machine.current_state == null:
		return _last_area_state.duplicate(true)
	var state := state_machine.current_state
	# Save the logical result of a reaction, never replay its one-shot events.
	if state is BouncingBlockState:
		state = state.return_state
	return {"state": StringName(state.name)} if state != null else {}


func shutdown() -> void:
	if is_shutdown:
		return
	# Preserve logical progress if tree-exit cleanup precedes the level snapshot.
	_last_area_state = capture_area_state()
	super()

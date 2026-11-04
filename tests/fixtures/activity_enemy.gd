extends BaseEntity
var frame_ticks: int = 0
func _process(delta: float) -> void:
	frame_ticks += 1
	super(delta)

var physics_ticks: int = 0
func _physics_process(delta: float) -> void:
	physics_ticks += 1
	super(delta)

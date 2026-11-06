class_name QuestionBlock
extends BaseBlock

const BLOCK_COIN := preload("res://scenes/entities/blocks/question/block_coin.gd")

var power_up_scene: PackedScene


func _ready() -> void:
	$StateMachine/Bouncing.entered.connect(_release_reward)
	super()


func _release_reward() -> void:
	if power_up_scene != null:
		_release_power_up()
		return
	GameHandler.award_coin()
	var coin := BLOCK_COIN.new()
	get_parent().add_child(coin)
	coin.global_position = global_position + Vector2(8, -8)
	coin.reset_physics_interpolation()


func _release_power_up() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevel:
		ancestor = ancestor.get_parent()
	var level := ancestor as BaseLevel
	if level == null:
		return
	var instance := power_up_scene.instantiate()
	var power_up := instance as PowerUp
	if power_up == null:
		instance.free()
		push_error("Question block reward must inherit PowerUp.")
		return
	if not level.try_claim_spawn_slot(&"power_up", power_up, true):
		power_up.free()
		return
	power_up.visual_theme = visual_theme
	power_up.position = position
	power_up.begin_emergence()
	get_parent().add_child(power_up)
	get_parent().move_child(power_up, get_index())
	power_up.reset_physics_interpolation()

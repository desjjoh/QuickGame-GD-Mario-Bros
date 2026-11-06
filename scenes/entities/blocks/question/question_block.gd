extends BaseBlock

const BLOCK_COIN := preload("res://scenes/entities/blocks/question/block_coin.gd")


func _ready() -> void:
	$StateMachine/Bouncing.entered.connect(_release_coin)
	super()


func _release_coin() -> void:
	GameHandler.award_coin()
	var coin := BLOCK_COIN.new()
	get_parent().add_child(coin)
	coin.global_position = global_position + Vector2(8, -8)
	coin.reset_physics_interpolation()

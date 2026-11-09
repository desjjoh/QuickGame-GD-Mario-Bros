class_name QuestionBlock
extends BaseBlock

const BLOCK_COIN := preload("res://scenes/entities/blocks/question/block_coin.gd")
const TIMED_COIN_TICKS := 231

var power_up_scene: PackedScene
var reward_kind: BlockReward.Kind = BlockReward.Kind.COIN
var reward_started := false
var reward_ticks_remaining := 0
var _started_frame := -1
var _bounce_reward_claimed := false


func configure_reward(value: Resource) -> void:
	var reward := BlockReward.resolve(value)
	reward_kind = reward.kind
	power_up_scene = reward.power_up_scene if reward.kind == BlockReward.Kind.POWER_UP else null


func _ready() -> void:
	$StateMachine/Bouncing.entered.connect(_release_reward)
	$StateMachine/Active.entered.connect(_allow_reward)
	super()
	if reward_kind == BlockReward.Kind.TIMED_COINS:
		var level := BaseLevel.containing(self)
		if level != null:
			level.register_reward_timer(self)


func _allow_reward() -> void:
	_bounce_reward_claimed = false


func advance_reward_timer() -> void:
	if (
		reward_started
		and reward_ticks_remaining > 0
		and Engine.get_physics_frames() != _started_frame
	):
		reward_ticks_remaining -= 1


func capture_area_state() -> Dictionary:
	var data := super.capture_area_state()
	if reward_kind == BlockReward.Kind.TIMED_COINS:
		data["reward_started"] = reward_started
		data["reward_ticks_remaining"] = reward_ticks_remaining
	return data


func restore_area_state(data: Dictionary) -> void:
	super.restore_area_state(data)
	reward_started = data.get("reward_started", false)
	reward_ticks_remaining = clampi(data.get("reward_ticks_remaining", 0), 0, TIMED_COIN_TICKS)


func _release_reward() -> void:
	if _bounce_reward_claimed or is_shutdown:
		return
	_bounce_reward_claimed = true
	if reward_kind == BlockReward.Kind.TIMED_COINS:
		if not reward_started:
			reward_started = true
			reward_ticks_remaining = TIMED_COIN_TICKS
			_started_frame = Engine.get_physics_frames()
		$StateMachine/Bouncing.return_state = (
			$StateMachine/Active if reward_ticks_remaining > 0 else $StateMachine/Inactive
		)
	# Preserve the current artwork unless this hit consumes the final reward.
	if $StateMachine/Bouncing.return_state == $StateMachine/Inactive:
		sprite.texture = resolve_texture($StateMachine/Inactive.sprite_texture)
	if power_up_scene != null:
		_release_power_up()
		return
	GameHandler.award_coin()
	if is_shutdown or not is_inside_tree():
		return
	var coin := BLOCK_COIN.new()
	get_parent().add_child(coin)
	coin.global_position = global_position + Vector2(8, -8)
	coin.reset_physics_interpolation()


func _release_power_up() -> void:
	var level := BaseLevel.containing(self)
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

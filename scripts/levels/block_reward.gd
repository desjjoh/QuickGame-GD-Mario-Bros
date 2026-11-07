class_name BlockReward
extends Resource
## Shared authoring data; live countdown state belongs to each block.

enum Kind { COIN, TIMED_COINS, POWER_UP }
@export var kind: Kind = Kind.COIN
@export var power_up_scene: PackedScene


static func resolve(value: Resource) -> BlockReward:
	if value is BlockReward:
		return value
	var reward := BlockReward.new()
	# Preserve existing painted 1-Up assignments stored as PackedScenes.
	if value is PackedScene:
		reward.kind = Kind.POWER_UP
		reward.power_up_scene = value
	return reward

class_name BlockReward
extends Resource
## Shared authoring data; live countdown state belongs to each block.

enum Kind { COIN, TIMED_COINS, POWER_UP, TIERED_POWER_UP }
const SUPER_MUSHROOM_PATH := "res://scenes/entities/powerups/super_mushroom.tscn"
const FIRE_FLOWER_PATH := "res://scenes/entities/powerups/fire_flower.tscn"
@export var kind: Kind = Kind.COIN
@export var power_up_scene: PackedScene


static func resolve(value: Resource) -> BlockReward:
	if value is BlockReward:
		if value.kind != Kind.POWER_UP or not _is_super_mushroom(value.power_up_scene):
			return value
	var reward := BlockReward.new()
	# Older painted rewards store a scene directly.
	var scene := value.power_up_scene if value is BlockReward else value as PackedScene
	if _is_super_mushroom(scene):
		reward.kind = Kind.TIERED_POWER_UP
	elif scene != null:
		reward.kind = Kind.POWER_UP
		reward.power_up_scene = scene
	return reward


static func _is_super_mushroom(scene: PackedScene) -> bool:
	return scene != null and scene.resource_path == SUPER_MUSHROOM_PATH

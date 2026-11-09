extends RefCounted
## Absolute priorities in the world/HUD canvas. Background and scenery are routed separately.

const BEHIND_WORLD := 0
const WORLD := 1
const AVAILABLE_ITEM := 2
const REWARD_EFFECT := 3
const ENEMY := 4
const HUD := 5
const PLAYER := 6


static func apply(item: CanvasItem, priority: int) -> void:
	item.z_as_relative = false
	item.z_index = priority

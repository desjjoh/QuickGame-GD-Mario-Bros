extends RefCounted
## Absolute priorities in the world/HUD canvas. Background and scenery are routed separately.

const BEHIND_WORLD := 0
const WORLD := 1
const BOUNCING_BLOCK := 2
const AVAILABLE_ITEM := 3
const REWARD_EFFECT := 4
const ENEMY := 5
const HUD := 6
const PLAYER := 7
const FIREBALL := 8


static func apply(item: CanvasItem, priority: int) -> void:
	item.z_as_relative = false
	item.z_index = priority

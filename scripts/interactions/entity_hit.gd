class_name EntityHit
extends RefCounted
## One offensive contact. Receivers decide whether it activates them.

var attacker: BaseEntity
var maneuver: StringName
var direction: Vector2
var strength: float
## Live target box selected by the fireball scan, before screen clipping.
var fireball_target := Rect2()
## The block that delivered a bump, separate from the actor that struck it.
var struck_block: BaseEntity


func _init(source: BaseEntity, kind: StringName, travel: Vector2, power: float = 1.0) -> void:
	attacker = source
	maneuver = kind
	direction = travel
	strength = power

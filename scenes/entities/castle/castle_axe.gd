class_name CastleAxe
extends BaseEntity

signal touched(player: BasePlayer)

var _claimed := false


func touch(player: BasePlayer) -> void:
	if _claimed or is_shutdown or gameplay_suspended:
		return
	_claimed = true
	hide()
	$Body.set_deferred("collision_layer", 0)
	$Presentation/PaletteAnimation.set_enabled(false)
	touched.emit(player)

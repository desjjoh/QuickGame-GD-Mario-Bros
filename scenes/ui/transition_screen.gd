extends Control
## Hosts one presentation scene. Leaves the existing viewport background untouched.
var presentation: Control

func show_presentation(scene: PackedScene) -> bool:
 clear_presentation()
 if scene == null: return true
 var instance := scene.instantiate()
 if not instance is Control:
  instance.free()
  return false
 presentation = instance as Control
 add_child(presentation)
 return true

func clear_presentation() -> void:
 var previous := presentation
 presentation = null
 if is_instance_valid(previous):
  previous.hide()
  previous.queue_free()

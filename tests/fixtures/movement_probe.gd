extends Mario
## Count actual body integration calls without changing production motion.
var body_steps: int = 0

func move_body() -> void:
	body_steps += 1
	super()

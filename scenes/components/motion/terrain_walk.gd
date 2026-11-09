extends RefCounted
## Steps a terrain body at the requested horizontal speed and reports wall contact.


static func step(body: CharacterBody2D, horizontal_speed: float) -> bool:
	body.velocity.x = horizontal_speed
	body.move_and_slide()
	return body.is_on_wall()

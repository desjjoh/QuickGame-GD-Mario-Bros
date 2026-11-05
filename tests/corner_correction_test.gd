extends Node


func _ready() -> void:
	var platform := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16, 16)
	collider.shape = box
	platform.position = Vector2(72, 88)
	platform.add_child(collider)
	add_child(platform)
	var mario := load("res://scenes/player/mario (small)/mario.tscn").instantiate() as BasePlayer
	add_child(mario)
	# Audio playback is covered by jump_test; isolate collision geometry here.
	mario.ceiling_bump_sound = null
	mario.set_physics_process(false)
	await get_tree().physics_frame
	for side in [-1.0, 1.0]:
		mario.body.global_position = Vector2(59 if side < 0 else 86, 82)
		mario.body.velocity = Vector2(-side * 120, 60)
		mario.move_body()
		assert(mario.body.is_on_floor(), "Shallow foot overlap must land from either corner.")
		assert(mario.body.global_position.y <= 80.1)
		assert(is_equal_approx(mario.body.velocity.x, -side * 120))
		# Reset floor flags in open space before testing an upward corner.
		mario.body.global_position = Vector2(30, 120)
		mario.body.velocity = Vector2(0, -60)
		mario.body.move_and_slide()
		mario.body.global_position = Vector2(60 if side < 0 else 84, 110.2)
		mario.body.velocity = Vector2(0, -240)
		mario.move_body()
		assert(mario.body.velocity.y < 0, "An unobstructed center head probe must pass the corner.")
		assert(mario.body.global_position.x < 60 if side < 0 else mario.body.global_position.x > 84)
		await get_tree().physics_frame
	# Feet can start above the ledge and cross its top during this one step.
	for side in [-1.0, 1.0]:
		mario.body.global_position = Vector2(30, 120)
		mario.body.velocity = Vector2(0, -60)
		mario.body.move_and_slide()
		mario.body.global_position = Vector2(58 if side < 0 else 87, 78.5)
		mario.body.velocity = Vector2(-side * 120, 180)
		mario.move_body()
		assert(mario.body.is_on_floor(), "A descending top crossing must land on the current tick.")
		assert(mario.body.global_position.y <= 80.1)
		assert(
			is_equal_approx(mario.body.velocity.x, -side * 120),
			"A top crossing must preserve horizontal momentum."
		)
	mario.body.global_position = Vector2(72, 110.2)
	mario.body.velocity = Vector2(0, -240)
	mario.move_body()
	assert(is_equal_approx(mario.body.velocity.y, 3.75), "Centered ceiling hit must still bump.")
	assert(mario.body.global_position.x == 72.0)
	for feet_y in [85.0, 90.0]:
		mario.body.global_position = Vector2(59, feet_y)
		mario.body.velocity = Vector2(120, 60)
		mario.move_body()
		assert(mario.body.global_position.y >= feet_y, "Deep wall contacts must not lift Mario.")
	mario.body.global_position = Vector2(50, 82)
	mario.body.velocity = Vector2(0, 60)
	mario.move_body()
	assert(mario.body.global_position.y > 82, "A complete miss must remain a fall.")
	# A four-pixel fall cannot borrow this tick's previous, shallower depth.
	mario.body.global_position = Vector2(30, 120)
	mario.body.velocity = Vector2(0, -60)
	mario.body.move_and_slide()
	mario.body.global_position = Vector2(59, 81.2)
	mario.body.velocity = Vector2(120, 240)
	mario.move_body()
	assert(
		not mario.body.is_on_floor(),
		"Projected depth beyond four pixels must reject landing rescue."
	)
	assert(mario.body.global_position.y > 84.0)
	var ceiling := StaticBody2D.new()
	var ceiling_shape := CollisionShape2D.new()
	ceiling_shape.shape = box
	ceiling.position = Vector2(72, 60)
	ceiling.add_child(ceiling_shape)
	add_child(ceiling)
	await get_tree().physics_frame
	mario.body.global_position = Vector2(59, 82)
	mario.body.velocity = Vector2(120, 60)
	mario.move_body()
	assert(
		mario.body.global_position.y >= 82,
		"Landing assistance must reject a space below a low ceiling."
	)
	mario.free()
	platform.free()
	ceiling.free()
	print(
		"PASS: two-sided shallow landings, preserved momentum, two-sided head corner escape, centered bump, deep-wall rejection, and misses."
	)
	get_tree().quit()

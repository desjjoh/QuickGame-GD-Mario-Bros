extends Node


func solid(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.position = center
	body.add_child(collision)
	add_child(body)


func _ready() -> void:
	var mario := load("res://scenes/player/mario/mario.tscn").instantiate() as BasePlayer
	add_child(mario)
	mario.set_physics_process(false)
	# A 16-pixel vertical gap between two solid walls.
	solid(Vector2(40, 96), Vector2(16, 192))
	solid(Vector2(72, 96), Vector2(16, 192))
	solid(Vector2(8, 208), Vector2(16, 16))
	await get_tree().physics_frame
	mario.body.global_position = Vector2(56, 40)
	assert(
		not mario.body.test_move(mario.body.global_transform, Vector2(0, 100)),
		"Mario must fit inside a one-tile vertical gap."
	)
	# Sprite still overlaps the ledge at x=23, but the narrower body does not.
	mario.body.global_position = Vector2(20, 200)
	for frame in range(3):
		mario.body.velocity = Vector2(0, 30)
		mario.body.move_and_slide()
		await get_tree().physics_frame
	assert(mario.body.is_on_floor())
	mario.body.global_position.x = 23.0
	for frame in range(3):
		mario.body.velocity = Vector2(0, 30)
		mario.body.move_and_slide()
		await get_tree().physics_frame
	assert(not mario.body.is_on_floor(), "Sprite overlap alone must not support Mario on a ledge.")
	mario.free()
	print("PASS: one-tile gap clearance and falling when only sprite edges overlap a ledge.")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

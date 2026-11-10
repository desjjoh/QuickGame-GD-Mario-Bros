extends Node


func _ready() -> void:
	var body := CharacterBody2D.new()
	add_child(body)
	var values := MotionValues.new()
	values.body = body
	add_child(values)
	var vertical := VerticalMovementComponent.new()
	add_child(vertical)
	var samples: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/vertical_nes_writes.json")
	)
	assert(samples.size() > 100)
	for sample: Dictionary in samples:
		vertical.reset_fraction()
		vertical.position_fraction = int(sample.position_fraction)
		body.global_position.y = float(sample.y)
		body.velocity.y = (float(sample.speed) + float(sample.fraction) / 256.0) * 60.0
		values.base_gravity = float(sample.force) * 3600.0 / 256.0
		var next_speed := vertical.prepare_step(values, 1.0 / 60.0)
		var label: String = sample.source + ":" + str(sample.frame)
		assert(
			body.global_position.y + body.velocity.y / 60.0 == float(sample.next_y),
			"Exact position carry: " + label
		)
		assert(vertical.integer_speed == int(sample.next_speed), "Exact speed byte: " + label)
		assert(
			vertical.speed_fraction == int(sample.next_fraction), "Exact speed fraction: " + label
		)
		assert(
			vertical.position_fraction == int(sample.next_position_fraction),
			"Exact position fraction: " + label
		)
		assert(
			next_speed == (float(sample.next_speed) + float(sample.next_fraction) / 256.0) * 60.0
		)
	print("vertical_fraction_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

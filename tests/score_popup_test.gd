extends Node2D

const POPUP := preload("res://scenes/components/presentation/score_popup.tscn")


func _ready() -> void:
	var world := Node2D.new()
	world.position = Vector2(19, 31)
	add_child(world)
	var rows := [[100, 1000], [200, 2000], [400, 4000], [500, 5000], [800, 8000]]
	for row in range(rows.size()):
		for column in range(2):
			var popup = POPUP.instantiate()
			world.add_child(popup)
			assert(not popup.visible)
			var point := Vector2(80 + column * 40, 48 + row * 16)
			assert(popup.show_score(rows[row][column], point))
			assert(popup.visible and popup.global_position == point)
			assert(popup.region_rect == Rect2(column * 16, row * 8, 16, 8))
	var extra_life = POPUP.instantiate()
	world.add_child(extra_life)
	extra_life.show_one_up(Vector2(120, 128))
	assert(extra_life.visible and extra_life.global_position == Vector2(120, 128))
	assert(extra_life.region_rect == Rect2(16, 40, 16, 8))
	world.position.x += 10
	assert(extra_life.global_position == Vector2(130, 128))
	assert(not extra_life.show_score(300, Vector2.ZERO) and not extra_life.visible)
	extra_life.show_one_up(Vector2(120, 128))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		assert(frame.save_png("res://.godot/validation/score-popup.png") == OK)
	print("PASS: ten score tiles, 1 UP, world-space placement and unsupported amounts.")
	get_tree().quit()

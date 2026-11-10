extends Node

const FINISH_TEST := preload("res://tests/fixtures/finish_test.gd")


func render_frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("koopa_shadow_test: PASS")
		await FINISH_TEST.finish(get_tree())
		return
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.hide()
	var koopa := (
		load("res://scenes/entities/enemies/koopa/green_koopa.tscn").instantiate() as BaseEnemy
	)
	koopa.position = Vector2(128, 192)
	koopa.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	level.world_objects.add_child(koopa)
	koopa.set_gameplay_suspended(true)
	koopa.get_node("Presentation/WalkAnimationSync").set_enabled(false)
	koopa.animation_player.stop()
	var sheet := koopa.sprite.texture.get_image()
	for frame in range(2):
		koopa.sprite.frame = frame
		for phase in range(2):
			koopa.body.position.x = 8 + phase
			level.get_node("Systems/ShadowComposer").set_shadow_style(null)
			await render_frame()
			await render_frame()
			var baseline := get_viewport().get_texture().get_image()
			baseline.save_png("res://.godot/validation/koopa-none.png")
			for style_name in ["soft", "crisp", "outer_blur"]:
				level.get_node("Systems/ShadowComposer").set_shadow_style(
					load("res://assets/shadows/" + style_name + ".tres")
				)
				await render_frame()
				await render_frame()
				var styled := get_viewport().get_texture().get_image()
				# Opaque source pixels at integer placement must survive each style.
				for y in range(32):
					for x in range(16):
						if sheet.get_pixel(frame * 16 + x, y).a != 1.0:
							continue
						var at := Vector2i(roundf(koopa.sprite.global_position.x) - 8 + x, 176 + y)
						var before := baseline.get_pixelv(at)
						var after := styled.get_pixelv(at)
						assert(
							(
								absf(before.r - after.r) < 0.01
								and absf(before.g - after.g) < 0.01
								and absf(before.b - after.b) < 0.01
							),
							(
								"style="
								+ style_name
								+ " frame="
								+ str(frame)
								+ " phase="
								+ str(phase)
								+ " pixel="
								+ str(at)
								+ " before="
								+ str(before)
								+ " after="
								+ str(after)
							)
						)
				if phase == 0:
					assert(
						(
							styled.save_png(
								(
									"res://.godot/validation/koopa-"
									+ style_name
									+ "-"
									+ str(frame)
									+ ".png"
								)
							)
							== OK
						)
					)
	level.queue_free()
	await get_tree().process_frame
	print("koopa_shadow_test: PASS")
	await FINISH_TEST.finish(get_tree())

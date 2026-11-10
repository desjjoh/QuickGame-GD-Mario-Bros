extends RefCounted

const LOGICAL_SIZE := Vector2(256, 240)


static func sample(shot: Image, x: int, y: int) -> Color:
	# Map the logical pixel center into the aspect-fitted native capture.
	var size := Vector2(shot.get_size())
	var scale := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	var offset := (size - LOGICAL_SIZE * scale) / 2.0
	var point := Vector2i(offset + (Vector2(x, y) + Vector2(0.5, 0.5)) * scale)
	return shot.get_pixelv(point)

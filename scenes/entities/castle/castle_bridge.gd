class_name CastleBridge
extends Node2D

signal collapse_finished

var collapse_complete := false
var _collapse_started := false
var _remaining_cells: Array[Vector2i] = []

@onready var axe: CastleAxe = $Axe
@onready var _deck: TileMapLayer = $Deck


func collapse_next_piece() -> void:
	if collapse_complete:
		return
	if not _collapse_started:
		_collapse_started = true
		_remaining_cells = _deck.get_used_cells()
		_remaining_cells.sort_custom(_is_left_of)
		$Chain.hide()
	else:
		var cell: Vector2i = _remaining_cells.pop_back()
		_deck.erase_cell(cell)
	if _remaining_cells.is_empty():
		collapse_complete = true
		collapse_finished.emit()


static func _is_left_of(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

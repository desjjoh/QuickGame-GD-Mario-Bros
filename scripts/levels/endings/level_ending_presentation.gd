class_name LevelEndingPresentation
extends Node
## Level-owned ending contract; different presentations share acceptance/finish.


func bind_area(_area: BaseLevelArea) -> void:
	pass


func bind_entity(_entity: BaseEntity, _cell: Vector2i, _area: BaseLevelArea) -> void:
	pass


func keeps_area_music_on_start() -> bool:
	return false


func start(_level: BaseLevel, _player: BasePlayer, _source: BaseEntity) -> bool:
	return false


func cancel() -> void:
	pass


func is_finished() -> bool:
	return false

class_name BaseLevel
extends CanvasGroup
## Shared foundation for playable levels.

@export_group("Spawning")
@export var player_scene: PackedScene
@export var entity_scenes: Dictionary[StringName, PackedScene] = {}
@export_group("Screen Bounds")
@export var keep_player_on_screen: bool = true
@export_range(0.0, 64.0, 1.0) var horizontal_screen_inset: float = 7.0

var player: BasePlayer
var is_shutdown: bool = false
var _layout_spawned: bool = false

@onready var player_spawn: Marker2D = $Players/PlayerSpawn
@onready var players: Node2D = $Players
@onready var entity_layout: TileMapLayer = $Layouts/EntityLayout
@onready var world_objects: Node2D = $WorldObjects


func _ready() -> void:
	# Keep gameplay in one CanvasGroup Z band, with players drawn last.
	move_child(world_objects, get_child_count() - 1)
	move_child(players, get_child_count() - 1)
	# Player state physics runs at priority 0; clamp its moving body afterward.
	process_physics_priority = 100
	# All level children are ready before the level's _ready() runs.
	spawn_layout_entities()
	spawn_player()
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player):
		camera.reset_target(player.body)


func spawn_layout_entities() -> void:
	if is_shutdown or _layout_spawned:
		return
	_layout_spawned = true
	# Markers remain editable in the scene, but only entities render at runtime.
	entity_layout.hide()
	if entity_layout.tile_set == null:
		return
	if entity_layout.tile_set.get_custom_data_layer_by_name("entity_id") < 0:
		push_error("EntityLayout TileSet needs an entity_id custom-data layer.")
		return
	for cell: Vector2i in entity_layout.get_used_cells():
		var data := entity_layout.get_cell_tile_data(cell)
		if data == null:
			continue
		var entity_id := StringName(str(data.get_custom_data("entity_id")))
		var scene: PackedScene = entity_scenes.get(entity_id)
		if scene == null:
			push_error("EntityLayout cell %s has unmapped entity_id '%s'." % [cell, entity_id])
			continue
		var instance := scene.instantiate()
		if not instance is BaseEntity:
			push_error("EntityLayout scenes must inherit BaseEntity: %s" % entity_id)
			instance.free()
			continue
		instance.name = "%s_%s_%s" % [entity_id, cell.x, cell.y]
		# Block/entity marker origins are the top-left of each grid cell.
		var local_origin := entity_layout.map_to_local(cell) - Vector2(entity_layout.tile_set.tile_size) / 2.0
		instance.position = world_objects.to_local(entity_layout.to_global(local_origin))
		world_objects.add_child(instance)


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d() as LevelCamera
	if camera != null and is_instance_valid(player) and not player.is_shutdown:
		camera.follow_target(player.body)
	clamp_player_to_camera()


func clamp_player_to_camera() -> void:
	if is_shutdown or not keep_player_on_screen or not is_instance_valid(player) or not is_instance_valid(player.body):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.global_position.x if camera is LevelCamera else camera.get_screen_center_position().x
	var half_width := get_viewport_rect().size.x / camera.zoom.x / 2.0
	var inset := minf(horizontal_screen_inset, half_width)
	var player_position := player.body.global_position
	var left_edge := center - half_width + inset
	var right_edge := center + half_width - inset
	# Resolve the boundary like a wall: cancel motion into it, even if input
	# has already reversed. Preserve motion away from it and vertical speed.
	if (player_position.x <= left_edge and player.body.velocity.x < 0.0) or (player_position.x >= right_edge and player.body.velocity.x > 0.0):
		player.body.velocity.x = 0.0
	player_position.x = clampf(player_position.x, center - half_width + inset, center + half_width - inset)
	player.body.global_position = player_position


func spawn_player() -> BasePlayer:
	if is_shutdown:
		return null
	if is_instance_valid(player):
		return player
	if player_scene == null:
		return null

	var instance := player_scene.instantiate()
	if not instance is BasePlayer:
		push_error("The level's player scene must inherit BasePlayer.")
		instance.free()
		return null

	player = instance as BasePlayer
	player.position = players.to_local(player_spawn.global_position)
	players.add_child(player)
	player.reset_physics_interpolation()
	if GameHandler.current_level == self:
		GameHandler.current_player = player
	return player


func _exit_tree() -> void:
	shutdown()
	if GameHandler.current_level == self:
		GameHandler.current_level = null
		GameHandler.current_player = null


func shutdown() -> void:
	if is_shutdown:
		return
	is_shutdown = true
	set_process(false)
	set_physics_process(false)
	_shutdown_entities(self)


func _shutdown_entities(parent: Node) -> void:
	for child in parent.get_children():
		if child is BaseEntity:
			child.shutdown()
		_shutdown_entities(child)

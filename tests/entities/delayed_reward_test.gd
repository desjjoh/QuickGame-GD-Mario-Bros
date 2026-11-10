extends Node

signal physics_finished
const GOOMBA := preload("res://scenes/entities/enemies/goomba/goomba.tscn")
const ONE_UP := preload("res://scenes/entities/powerups/one_up_mushroom.tscn")
const SUPER := preload("res://scenes/entities/powerups/super_mushroom.tscn")


func _physics_process(_delta: float) -> void:
	physics_finished.emit()


func ticks(count: int) -> void:
	for index in range(count):
		await physics_finished


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 2000
	var level := load("res://tests/fixtures/sandbox_level.tscn").instantiate() as BaseLevel
	level.entity_layout.clear()
	level.get_node("Areas/MainArea/Layouts/EnemyLayout").clear()
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.set_physics_process(false)
	var score := GameHandler.player_status.score
	var lives := GameHandler.player_status.lives
	var enemy := GOOMBA.instantiate() as BaseEnemy
	level.world_objects.add_child(enemy)
	enemy.award_score(100, Vector2.ZERO)
	level.world_objects.get_node("ScorePopup").free()
	enemy.free()
	assert(GameHandler.player_status.score == score)
	await ticks(5)
	assert(GameHandler.player_status.score == score)
	get_tree().paused = true
	await ticks(8)
	assert(GameHandler.player_status.score == score)
	get_tree().paused = false
	await ticks(1)
	assert(GameHandler.player_status.score == score + 100)
	await ticks(8)
	assert(GameHandler.player_status.score == score + 100)
	# Static entity-owned life awards remain callable after their actor is freed.
	enemy = GOOMBA.instantiate() as BaseEnemy
	level.world_objects.add_child(enemy)
	enemy.award_extra_life(Vector2.ZERO)
	enemy.free()
	var mushroom := ONE_UP.instantiate() as Mushroom
	level.world_objects.add_child(mushroom)
	mushroom._grant_reward(level.player)
	mushroom.free()
	var super_mushroom := SUPER.instantiate() as SuperMushroom
	level.world_objects.add_child(super_mushroom)
	super_mushroom._grant_reward(level.player)
	super_mushroom.free()
	assert(GameHandler.player_status.lives == lives)
	await ticks(5)
	assert(GameHandler.player_status.lives == lives)
	assert(GameHandler.player_status.score == score + 100)
	await ticks(1)
	assert(GameHandler.player_status.lives == lives + 2)
	assert(GameHandler.player_status.score == score + 1100)
	await ticks(8)
	assert(GameHandler.player_status.lives == lives + 2)
	# No pending award may cross a level shutdown into a later run.
	enemy = GOOMBA.instantiate() as BaseEnemy
	level.world_objects.add_child(enemy)
	enemy.award_score(500, Vector2.ZERO)
	level.shutdown()
	await ticks(8)
	assert(GameHandler.player_status.score == score + 1100)
	level.free()
	await get_tree().process_frame
	print("delayed_reward_test: PASS")
	await preload("res://tests/fixtures/finish_test.gd").finish(get_tree())

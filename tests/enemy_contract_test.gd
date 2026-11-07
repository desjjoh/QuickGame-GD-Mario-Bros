extends Node


func make_enemy() -> BaseEnemy:
	var enemy := (
		preload("res://scenes/entities/enemies/base/base_enemy.tscn").instantiate() as BaseEnemy
	)
	enemy.set_script(preload("res://tests/fixtures/reactive_enemy.gd"))
	add_child(enemy)
	return enemy


func _ready() -> void:
	var actor := make_enemy()
	var other := make_enemy()
	other.position.x = 100
	var defeats: Array[EntityHit] = []
	var contacts: Array[BaseEnemy] = []
	var other_contacts: Array[BaseEnemy] = []
	actor.defeated.connect(func(hit: EntityHit): defeats.append(hit))
	actor.enemy_contact.connect(func(enemy: BaseEnemy): contacts.append(enemy))
	other.enemy_contact.connect(func(enemy: BaseEnemy): other_contacts.append(enemy))
	var reaction := EntityHit.new(null, &"react", Vector2.RIGHT)
	assert(not actor.receive_hit(null))
	assert(not actor.receive_hit(EntityHit.new(null, &"unsupported", Vector2.RIGHT)))
	assert(actor.receive_hit(reaction))
	assert(actor.receive_hit(reaction))
	assert(actor.reactions == 2 and not actor.nested_hit_accepted)
	assert(not actor._defeated and defeats.is_empty())
	assert(actor._blocks_enemy_contact())
	actor._on_enemy_contact(other.get_node("Body/EnemyContact"))
	assert(contacts == [other])
	actor._on_enemy_contact(actor.get_node("Body/EnemyContact"))
	assert(contacts.size() == 1)
	actor.set_gameplay_suspended(true)
	assert(not actor.receive_hit(reaction))
	actor._on_enemy_contact(other.get_node("Body/EnemyContact"))
	assert(contacts.size() == 1)
	actor.set_gameplay_suspended(false)
	actor.set_activity_suspended(true)
	assert(not actor.receive_hit(reaction))
	actor.set_activity_suspended(false)
	var lethal := EntityHit.new(other, &"defeat", Vector2.RIGHT)
	assert(actor.receive_hit(lethal))
	assert(actor._defeated and defeats == [lethal])
	assert(not actor.receive_hit(reaction))
	assert(not actor.mark_defeated(lethal) and defeats.size() == 1)
	assert(not actor._blocks_enemy_contact())
	actor._on_enemy_contact(other.get_node("Body/EnemyContact"))
	assert(contacts.size() == 1)
	other._on_enemy_contact(actor.get_node("Body/EnemyContact"))
	assert(other_contacts.is_empty())
	var stopped := make_enemy()
	stopped.shutdown()
	assert(not stopped.receive_hit(reaction) and not stopped.mark_defeated(lethal))
	actor.queue_free()
	other.queue_free()
	stopped.queue_free()
	await get_tree().process_frame
	print("enemy_contract_test: PASS")
	get_tree().quit()

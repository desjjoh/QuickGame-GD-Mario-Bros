class_name BaseEnemy
extends SpawnableEntity
## Shared body and inherited entity state machine for live enemies.

signal enemy_contact
signal defeated(hit: EntityHit)

const STOMP_REBOUND := -240.0

@onready var body: CharacterBody2D = $Body
@onready var _enemy_contact_area: Area2D = $Body/EnemyContact
@onready var _player_contact_area := get_node_or_null("Body/PlayerContact") as Area2D
@onready var _block_hits: BlockHitReceiver = $Body/BlockHitReceiver

var _level: BaseLevel
var _defeated := false


func _ready() -> void:
	super()
	_enemy_contact_area.area_entered.connect(_on_enemy_contact)
	_block_hits.hit_received.connect(receive_hit)
	var ancestor := get_parent()
	while ancestor != null and not ancestor is BaseLevel:
		ancestor = ancestor.get_parent()
	_level = ancestor as BaseLevel
	if _level != null and is_instance_valid(_level.player):
		# The player shares the terrain layer. Enemy contact is handled separately.
		body.add_collision_exception_with(_level.player.body)


func _physics_process(delta: float) -> void:
	super(delta)
	if (
		_defeated or not _can_hurt_player() or _level == null
		or not is_instance_valid(_level.player)
	):
		return
	var player := _level.player
	if player.is_dead or player.is_shutdown or player.gameplay_suspended:
		return
	var tick := Engine.get_physics_frames()
	if tick % 2 != 0 or player.last_enemy_stomp_tick == tick:
		return
	if (
		_player_contact_area == null or player.enemy_hurtbox == null
		or not _player_contact_area.overlaps_area(player.enemy_hurtbox)
	):
		return
	if (
		player.body.velocity.y > 0.0
		and receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN))
	):
		player.last_enemy_stomp_tick = tick
		player.body.velocity.y = STOMP_REBOUND
		player.play_sound_effect(SoundHandler.get_sound(&"stomp"))
	else:
		_level.on_death(player, true)


func receive_hit(hit: EntityHit) -> bool:
	if (
		hit == null or _defeated or is_shutdown or is_queued_for_deletion()
		or gameplay_suspended or activity_suspended
	):
		return false
	if not _accept_hit(hit):
		return false
	_defeated = true
	defeated.emit(hit)
	return true


func _accept_hit(_hit: EntityHit) -> bool:
	return false


func _can_hurt_player() -> bool:
	return false


func _blocks_enemy_contact() -> bool:
	return not _defeated


func _on_enemy_contact(area: Area2D) -> void:
	if _defeated or is_shutdown or is_queued_for_deletion() or gameplay_suspended or activity_suspended:
		return
	var other := area.get_parent().get_parent() as BaseEnemy
	if (
		other != null and other._blocks_enemy_contact() and not other.is_shutdown
		and not other.is_queued_for_deletion()
	):
		enemy_contact.emit()

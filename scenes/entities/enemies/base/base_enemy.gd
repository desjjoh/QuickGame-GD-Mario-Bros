class_name BaseEnemy
extends SpawnableEntity
## Shared body and inherited entity state machine for live enemies.

signal enemy_contact(other: BaseEnemy)
signal defeated(hit: EntityHit)

const STOMP_REBOUND := -240.0
const SCORE_POPUP := preload("res://scenes/components/presentation/score_popup.tscn")

@onready var body: CharacterBody2D = $Body
@onready var _enemy_contact_area: Area2D = $Body/EnemyContact
@onready var _player_contact_area := get_node_or_null("Body/PlayerContact") as Area2D
@onready var _block_hits: BlockHitReceiver = $Body/BlockHitReceiver

var _level: BaseLevel
var _defeated := false
var _handling_hit := false
var _player_contact_latched := false


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
		_defeated
		or not _has_player_contact()
		or _level == null
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
		_player_contact_area == null
		or player.enemy_hurtbox == null
		or not _player_contact_area.overlaps_area(player.enemy_hurtbox)
	):
		_player_contact_latched = false
		return
	if _player_contact_latched:
		return
	_player_contact_latched = true
	_handle_player_contact(player)


func _handle_player_contact(player: BasePlayer) -> void:
	if _can_stomp(player) and receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN)):
		player.last_enemy_stomp_tick = Engine.get_physics_frames()
		player.body.velocity.y = STOMP_REBOUND
		player.play_sound_effect(SoundHandler.get_sound(&"stomp"))
	else:
		# Damage is guarded by the player, rather than the interaction latch.
		# This includes the first accepted injury: an unbroken overlap must become
		# dangerous again when its protection ends. Stomps/kicks retain their latch.
		_player_contact_latched = false
		player.receive_damage(self)


## Specialized enemies may accept a stomp under additional local conditions.
func _can_stomp(player: BasePlayer) -> bool:
	return player.body.velocity.y > 0.0


func receive_hit(hit: EntityHit) -> bool:
	if (
		hit == null
		or (_defeated and not _accepts_defeated_hit(hit))
		or _handling_hit
		or is_shutdown
		or is_queued_for_deletion()
		or gameplay_suspended
		or activity_suspended
	):
		return false
	_handling_hit = true
	var accepted := _accept_hit(hit)
	_handling_hit = false
	return accepted


## Call only for permanent defeat, not a shell transition or surviving damage.
func mark_defeated(hit: EntityHit) -> bool:
	if hit == null or _defeated or is_shutdown or is_queued_for_deletion():
		return false
	_defeated = true
	defeated.emit(hit)
	return true


func _accept_hit(_hit: EntityHit) -> bool:
	return false


## Optional physical reaction after permanent defeat; never clears that outcome.
func _accepts_defeated_hit(_hit: EntityHit) -> bool:
	return false


func award_stomp(hit: EntityHit, world_position: Vector2) -> void:
	if hit.attacker is BasePlayer:
		hit.attacker.award_enemy_stomp(self, world_position)
	else:
		award_score(100, world_position)


func award_score(points: int, world_position: Vector2) -> void:
	var popup := SCORE_POPUP.instantiate()
	get_parent().add_child(popup)
	popup.show_score(points, world_position)
	var rise := popup.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_property(popup, "position:y", popup.position.y - 24.0, 0.8)
	rise.tween_callback(popup.queue_free)
	GameHandler.add_score(points)


func _can_hurt_player() -> bool:
	return false


func _has_player_contact() -> bool:
	return _can_hurt_player()


func is_moving_shell() -> bool:
	return false


func away_from_attacker(hit: EntityHit) -> float:
	var origin := body.global_position
	if hit.attacker is BaseEnemy or hit.attacker is BasePlayer:
		origin = hit.attacker.body.global_position
	elif is_instance_valid(hit.attacker):
		origin = hit.attacker.global_position
	return -1.0 if body.global_position.x < origin.x else 1.0


func award_extra_life(world_position: Vector2) -> void:
	var popup := SCORE_POPUP.instantiate()
	get_parent().add_child(popup)
	popup.show_one_up(world_position)
	var rise := popup.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_property(popup, "position:y", popup.position.y - 24.0, 0.8)
	rise.tween_callback(popup.queue_free)
	GameHandler.set_lives(GameHandler.player_status.lives + 1)
	SoundHandler.play_reward(&"extra_life")


func _blocks_enemy_contact() -> bool:
	return not _defeated


func _on_enemy_contact(area: Area2D) -> void:
	if (
		_defeated
		or is_shutdown
		or is_queued_for_deletion()
		or gameplay_suspended
		or activity_suspended
	):
		return
	var other := area.get_parent().get_parent() as BaseEnemy
	if (
		other != null
		and other != self
		and other._blocks_enemy_contact()
		and not other.is_shutdown
		and not other.is_queued_for_deletion()
	):
		enemy_contact.emit(other)

class_name BaseEnemy
extends SpawnableEntity
## Shared body and inherited entity state machine for live enemies.

signal enemy_contact(other: BaseEnemy)
signal defeated(hit: EntityHit)

const DELAYED_REWARD := preload("res://scenes/components/interactions/delayed_reward.gd")
const DRAW_ORDER := preload("res://scenes/components/presentation/draw_order.gd")
const FIREBALL_TARGETS := &"fireball_targets"
const PLAYER_CONTACT := preload("res://scenes/components/interactions/player_contact.gd")
const STOMP_REBOUND := -240.0
const RISING_REWARD_POPUP := preload("res://scenes/components/presentation/rising_reward_popup.gd")

@onready var body: CharacterBody2D = $Body
@onready var _enemy_contact_area: Area2D = $Body/EnemyContact
@onready var _player_contact_area := get_node_or_null("Body/PlayerContact") as Area2D
@onready var _player_contact_shape := (
	get_node_or_null("Body/PlayerContact/CollisionShape2D") as CollisionShape2D
)
@onready var _block_hits: BlockHitReceiver = $Body/BlockHitReceiver

var _level: BaseLevel
var _defeated := false
var _handling_hit := false
var _player_contact_latched := false


func _ready() -> void:
	super()
	DRAW_ORDER.apply(sprite, DRAW_ORDER.ENEMY)
	add_to_group(FIREBALL_TARGETS)
	_enemy_contact_area.area_entered.connect(_on_enemy_contact)
	_block_hits.hit_handler = receive_hit
	_level = BaseLevel.containing(self)
	if _level != null:
		_level.ignore_player_body(body)


func _physics_process(delta: float) -> void:
	var player := _level.player if is_instance_valid(_level) else null
	var mario := player as Mario
	if is_instance_valid(mario) and mario.starman.is_active():
		# The NES checks contact before moving the enemy on a star hit.
		if _can_check_player_contact(player) and _touches_player_now(player):
			if receive_hit(EntityHit.new(player, &"star", Vector2.ZERO)):
				return
		super(delta)
		return
	_check_normal_player_contact(player)
	super(delta)


func _check_normal_player_contact(player: BasePlayer) -> void:
	if (
		_defeated
		or is_shutdown
		or gameplay_suspended
		or activity_suspended
		or not _has_player_contact()
		or not _can_check_player_contact(player)
	):
		return
	if not _touches_player_now(player):
		_player_contact_latched = false
		return
	if _player_contact_latched:
		return
	if player.last_enemy_stomp_tick == Engine.get_physics_frames():
		# The rebound changes velocity immediately, but this contact still belongs to the fall.
		if player.enemy_stomp_started_descending:
			_player_contact_latched = _receive_stomp(player)
		return
	_player_contact_latched = true
	_handle_player_contact(player)


func _can_check_player_contact(player: BasePlayer) -> bool:
	return (
		is_instance_valid(player)
		and not player.is_dead
		and not player.is_shutdown
		and not player.gameplay_suspended
		and PLAYER_CONTACT.is_check_tick()
	)


func _touches_player_now(player: BasePlayer) -> bool:
	return PLAYER_CONTACT.touches(_player_contact_area, player.enemy_hurtbox)


func _handle_player_contact(player: BasePlayer) -> void:
	var descending := player.body.velocity.y > 0.0
	if _can_stomp(player) and _receive_stomp(player):
		player.last_enemy_stomp_tick = Engine.get_physics_frames()
		player.enemy_stomp_started_descending = descending
		player.body.velocity.y = STOMP_REBOUND
		player.play_sound_effect(SoundHandler.get_sound(&"stomp"))
	else:
		# Damage is guarded by the player, rather than the interaction latch.
		# This includes the first accepted injury: an unbroken overlap must become
		# dangerous again when its protection ends. Stomps/kicks retain their latch.
		_player_contact_latched = false
		player.receive_damage(self)


func _receive_stomp(player: BasePlayer) -> bool:
	return receive_hit(EntityHit.new(player, &"stomp", Vector2.DOWN))


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


func is_defeated() -> bool:
	return _defeated


func _accept_hit(_hit: EntityHit) -> bool:
	return false


## Optional physical reaction after permanent defeat; never clears that outcome.
func _accepts_defeated_hit(_hit: EntityHit) -> bool:
	return false


## First drawn popup center, derived from the pre-reaction body origin.
func reward_popup_position(launch := false) -> Vector2:
	# The centered terrain body is 16 pixels below the NES enemy Y origin.
	# The first OAM row draws eight pixels above that origin, plus the two-pixel launch lift.
	return body.global_position.round() - Vector2(0, 22 if launch else 20)


func award_stomp(hit: EntityHit, world_position: Vector2) -> void:
	if hit.attacker is BasePlayer:
		hit.attacker.award_enemy_stomp(self, world_position)
	else:
		award_score(100, world_position)


func award_score(
	points: int,
	world_position: Vector2,
	delay_ticks: int = DELAYED_REWARD.DELAY_TICKS,
	defer_popup := false
) -> void:
	_configure_reward_popup(
		RISING_REWARD_POPUP.show_score(get_parent(), points, world_position, defer_popup)
	)
	DELAYED_REWARD.schedule(self, GameHandler.add_score.bind(points), delay_ticks)


func award_smack_defeat(points: int, world_position: Vector2) -> void:
	award_score(points, world_position, 5)
	play_sound_effect(SoundHandler.get_sound(&"enemy_smack"))


func can_contact_fireball() -> bool:
	return (
		not _defeated
		and not is_shutdown
		and not is_queued_for_deletion()
		and not gameplay_suspended
		and not activity_suspended
	)


## Shared target box for fireballs and moving shells.
func projectile_target_bounds() -> Rect2:
	if _player_contact_shape == null:
		return Rect2()
	return PLAYER_CONTACT.bounds(_player_contact_shape)


func fireball_target_boxes() -> Array[Rect2]:
	return [projectile_target_bounds()]


func fireball_box_origin_x(_bounds: Rect2) -> float:
	return body.global_position.x - 8.0


func _can_hurt_player() -> bool:
	return false


func _has_player_contact() -> bool:
	return _can_hurt_player()


func is_moving_shell() -> bool:
	return false


## Ordinary Goomba/Koopa OffscreenBoundsCheck, including its borrow/carry.
func is_outside_horizontal_cleanup(left: float, right: float) -> bool:
	var anchor := floorf(body.global_position.x - 8.0)
	var right_extension := 73.0 if left >= 73.0 else 72.0
	return anchor < left - 73.0 or anchor >= right + right_extension


func away_from_attacker(hit: EntityHit) -> float:
	var origin := body.global_position
	if hit.attacker is BaseEnemy or hit.attacker is BasePlayer:
		origin = hit.attacker.body.global_position
	elif is_instance_valid(hit.attacker):
		origin = hit.attacker.global_position
	return -1.0 if body.global_position.x < origin.x else 1.0


func award_extra_life(world_position: Vector2, defer_popup := false) -> void:
	_configure_reward_popup(
		RISING_REWARD_POPUP.show_one_up(get_parent(), world_position, defer_popup)
	)
	DELAYED_REWARD.schedule(self, _grant_extra_life)


func _configure_reward_popup(_popup: Sprite2D) -> void:
	pass


static func _grant_extra_life() -> void:
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
		and not is_moving_shell()
		and not other.is_moving_shell()
		and other._blocks_enemy_contact()
		and not other.is_shutdown
		and not other.is_queued_for_deletion()
	):
		enemy_contact.emit(other)

class_name CastleRescue
extends Node2D

@export var greeting_tick := 3
@export var message_tick := 131
@export var finish_tick := 382

var elapsed_ticks := 0

@onready var player_stop: Marker2D = $PlayerStop
@onready var _thanks: Label = $Messages/Thanks
@onready var _message: Label = $Messages/RescueMessage
@onready var _default_greeting := _thanks.text


func advance(character: GameHandler.PlayerCharacter) -> bool:
	elapsed_ticks += 1
	if elapsed_ticks == greeting_tick:
		var player_name := "LUIGI" if character == GameHandler.PlayerCharacter.LUIGI else "MARIO"
		_thanks.text = "THANK YOU %s!" % player_name
		_thanks.show()
	if elapsed_ticks == message_tick:
		_message.show()
	return elapsed_ticks >= finish_tick


func reset() -> void:
	elapsed_ticks = 0
	_thanks.text = _default_greeting
	_thanks.hide()
	_message.hide()

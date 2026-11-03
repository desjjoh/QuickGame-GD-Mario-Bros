extends TransportEntity
## Test portal deliberately chooses a state other than PipeEnter.
func get_transport_state(player: BasePlayer) -> PlayerTransportState:
	return player.state_machine.get_state(&"TestTravel") as PlayerTransportState

func exit_position() -> Vector2:
	return global_position + Vector2(16,0)

func exit_direction() -> Vector2:
	return Vector2.UP

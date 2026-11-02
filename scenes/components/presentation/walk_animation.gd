class_name WalkAnimationComponent
extends Node
## Velocity bands select cadence; the Run button does not directly affect it.
## The walk resource is authored with a base pose interval of 7/60 seconds.

@export var medium_speed_threshold: float = 52.5
@export var fast_speed_threshold: float = 105.0
@export_range(1, 60) var slow_frame_ticks: int = 7
@export_range(1, 60) var medium_frame_ticks: int = 4
@export_range(1, 60) var fast_frame_ticks: int = 2


func get_frame_ticks(horizontal_velocity: float) -> int:
	var speed := absf(horizontal_velocity)
	if speed >= fast_speed_threshold:
		return fast_frame_ticks
	if speed >= medium_speed_threshold:
		return medium_frame_ticks
	return slow_frame_ticks


func apply(animation_player: AnimationPlayer, horizontal_velocity: float) -> void:
	if animation_player != null:
		animation_player.speed_scale = 7.0 / float(get_frame_ticks(horizontal_velocity))


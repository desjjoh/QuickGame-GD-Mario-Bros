class_name WalkAnimationComponent
extends Node
## Velocity bands select cadence; the Run button does not directly affect it.
## The walk resource is authored with a base pose interval of 7/60 seconds.

@export var medium_speed_threshold: float = 52.5
@export var fast_speed_threshold: float = 105.0
@export_range(1, 60) var slow_frame_ticks: int = 7
@export_range(1, 60) var medium_frame_ticks: int = 4
@export_range(1, 60) var fast_frame_ticks: int = 2

var ticks_left := 0
var pose_index := 0


func get_frame_ticks(horizontal_velocity: float) -> int:
	var speed := absf(horizontal_velocity)
	if speed >= fast_speed_threshold:
		return fast_frame_ticks
	if speed >= medium_speed_threshold:
		return medium_frame_ticks
	return slow_frame_ticks


func tick() -> void:
	ticks_left = maxi(0, ticks_left - 1)


func apply_scripted_cadence(animation_player: AnimationPlayer, horizontal_velocity: float) -> void:
	animation_player.speed_scale = 7.0 / float(get_frame_ticks(horizontal_velocity))


func begin(animation_player: AnimationPlayer) -> void:
	pose_index = 0
	show_pose(animation_player)


func show_pose(animation_player: AnimationPlayer) -> void:
	# The atlas order is NES poses 1, 2, 0. Keep the clip for form texture mapping.
	var clip := animation_player.get_animation(&"walk")
	if not animation_player.is_playing() or animation_player.current_animation != &"walk":
		animation_player.play(&"walk")
	animation_player.speed_scale = 0.0
	animation_player.seek(clip.track_get_key_time(0, (pose_index + 2) % 3), true)


func advance_pose(animation_player: AnimationPlayer, horizontal_velocity: float) -> void:
	show_pose(animation_player)
	# Draw the current pose first. A reload advances the pose for the next tick.
	if ticks_left == 0:
		ticks_left = get_frame_ticks(horizontal_velocity)
		pose_index = (pose_index + 1) % 3

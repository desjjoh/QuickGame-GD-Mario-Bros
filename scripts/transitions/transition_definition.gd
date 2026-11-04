class_name TransitionDefinition
extends Resource
const Stage = preload("res://scripts/transitions/transition_stage.gd")
## Named presentation policy; the coordinator owns lifecycle and cancellation.
@export var id: StringName
@export_range(1, 3600, 1) var minimum_frames: int = 12
@export var allow_level_replacement: bool = false
@export var stages: Array[Stage] = []

func is_valid() -> bool:
 if id.is_empty() or minimum_frames < 1: return false
 for stage in stages:
  if stage == null or not stage.is_valid(): return false
 return true

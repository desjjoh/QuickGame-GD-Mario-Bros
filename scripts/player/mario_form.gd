class_name MarioForm
extends Resource
## Mario-specific data; declaring a capability does not implement its behavior.

@export var display_name: String = "Small"
@export var idle: Texture2D
@export var walk: Array[Texture2D] = []
@export var skid: Texture2D
@export var jump: Texture2D
@export var crouch: Texture2D
@export var climb: Array[Texture2D] = []
@export var growth_intermediate: Texture2D
@export var shrink_pose: Texture2D
@export var jump_cue: StringName = &"jump_small"
@export var sprite_position := Vector2(0, -7)
@export var standing_contact_size := Vector2(10, 12)
@export var standing_contact_position := Vector2(0, -6)
@export var crouched_contact_size := Vector2(10, 12)
@export var crouched_contact_position := Vector2(0, -6)
@export var can_crouch := false
@export var can_break_bricks := false

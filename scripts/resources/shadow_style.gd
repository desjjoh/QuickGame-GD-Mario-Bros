class_name ShadowStyle
extends Resource
## Shared compositor inputs. A null level style bypasses all shadow passes.

@export var display_name: String
@export var composite_material: ShaderMaterial
@export var horizontal_shader: Shader
@export var uses_blur: bool = true


## Read the authored Game selection without instantiating another game/session.
static func game_default() -> ShadowStyle:
	var state := (load("res://scenes/main/game.tscn") as PackedScene).get_state()
	var style: ShadowStyle
	var enabled := true
	for index in range(state.get_node_property_count(0)):
		var property := state.get_node_property_name(0, index)
		if property == &"shadow_style":
			style = state.get_node_property_value(0, index) as ShadowStyle
		elif property == &"shadow_shader_enabled":
			enabled = state.get_node_property_value(0, index)
	return style if enabled else null

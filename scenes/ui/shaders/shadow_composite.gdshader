shader_type canvas_item;
render_mode unshaded;

uniform sampler2D foreground_texture : repeat_disable, filter_nearest;
uniform sampler2D horizontal_texture : repeat_disable, filter_linear;
uniform vec2 shadow_offset = vec2(2.0);
uniform float blur_radius = 4.5;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.38);
uniform bool shadow_enabled = true;

void fragment() {
	vec2 pixel = 1.0 / vec2(textureSize(foreground_texture, 0));
	vec4 foreground = texture(foreground_texture, UV);
	vec2 shadow_uv = UV - shadow_offset * pixel;
	float alpha = 0.0;
	float total_weight = 0.0;
	for (int y = -6; y <= 6; y++) {
		float weight = exp(-float(y * y) / 8.0);
		vec2 tap = shadow_uv + vec2(0.0, float(y) * blur_radius / 6.0 * pixel.y);
		float inside = step(0.0, tap.x) * step(tap.x, 1.0)
			* step(0.0, tap.y) * step(tap.y, 1.0);
		alpha += texture(horizontal_texture, tap).r * weight * inside;
		total_weight += weight;
	}
	float shadow_alpha = alpha / total_weight * (shadow_enabled ? shadow_color.a : 0.0);
	float combined_alpha = foreground.a + shadow_alpha * (1.0 - foreground.a);
	// Transparent viewport color is premultiplied; emit straight color for canvas blending.
	vec3 premultiplied = foreground.rgb + shadow_color.rgb * shadow_alpha * (1.0 - foreground.a);
	COLOR = vec4(combined_alpha > 0.0001 ? premultiplied / combined_alpha : vec3(0.0), combined_alpha);
}

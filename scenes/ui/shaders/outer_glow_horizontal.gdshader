shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D foreground_texture : repeat_disable, filter_linear;
uniform float blur_radius = 6.0;

void fragment() {
	vec2 pixel = 1.0 / vec2(textureSize(foreground_texture, 0));
	float alpha = 0.0;
	float total_weight = 0.0;
	for (int x = -12; x <= 12; x++) {
		float weight = exp(-float(x * x) / 72.0);
		vec2 tap = UV + vec2(float(x) * blur_radius / 12.0 * pixel.x, 0.0);
		float inside = step(0.0, tap.x) * step(tap.x, 1.0);
		alpha += texture(foreground_texture, tap).a * weight * inside;
		total_weight += weight;
	}
	// Store the mask in red; opaque output avoids alpha blending it a second time.
	COLOR = vec4(alpha / total_weight, 0.0, 0.0, 1.0);
}

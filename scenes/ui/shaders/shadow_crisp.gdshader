shader_type canvas_item;
render_mode unshaded;

uniform sampler2D foreground_texture : repeat_disable, filter_nearest;
uniform sampler2D horizontal_texture : repeat_disable, filter_nearest;
uniform vec2 shadow_offset = vec2(2.0);
uniform float blur_radius = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.38);
uniform bool shadow_enabled = true;

// Interpolate only the silhouette; retain nearest sampling for visible artwork.
float silhouette(vec2 uv, vec2 pixel) {
	vec2 at = uv / pixel - vec2(0.5);
	vec2 base = floor(at);
	vec2 fraction = fract(at);
	vec2 origin = (base + vec2(0.5)) * pixel;
	float a = texture(foreground_texture, origin).a;
	float b = texture(foreground_texture, origin + vec2(pixel.x, 0.0)).a;
	float c = texture(foreground_texture, origin + vec2(0.0, pixel.y)).a;
	float d = texture(foreground_texture, origin + pixel).a;
	return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

void fragment() {
	vec2 pixel = 1.0 / vec2(textureSize(foreground_texture, 0));
	vec4 foreground = texture(foreground_texture, UV);
	vec2 tap = UV - shadow_offset * pixel;
	float inside = step(0.0, tap.x) * step(tap.x, 1.0) * step(0.0, tap.y) * step(tap.y, 1.0);
	float shadow_alpha = silhouette(tap, pixel) * inside * (shadow_enabled ? shadow_color.a : 0.0);
	float alpha = foreground.a + shadow_alpha * (1.0 - foreground.a);
	vec3 color = foreground.rgb + shadow_color.rgb * shadow_alpha * (1.0 - foreground.a);
	COLOR = vec4(alpha > 0.0001 ? color / alpha : vec3(0.0), alpha);
}

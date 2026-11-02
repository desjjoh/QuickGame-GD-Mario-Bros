shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 shadow_offset = vec2(2.0, 2.0);
uniform float blur_radius : hint_range(0.0, 6.0, 0.25) = 4.5;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.38);
uniform bool shadow_enabled = true;

void fragment() {
	vec4 foreground = textureLod(screen_texture, SCREEN_UV, 0.0);
	// Blur only the combined alpha mask; foreground pixels remain sharp.
	vec2 shadow_uv = SCREEN_UV - shadow_offset * SCREEN_PIXEL_SIZE;
	float shadow_alpha = 0.0;
	float total_weight = 0.0;
	for (int y = -6; y <= 6; y++) {
		for (int x = -6; x <= 6; x++) {
			vec2 tap = vec2(float(x), float(y));
			float weight = exp(-dot(tap, tap) / 8.0);
			shadow_alpha += textureLod(screen_texture,
				shadow_uv + tap * (blur_radius / 6.0) * SCREEN_PIXEL_SIZE, 0.0).a * weight;
			total_weight += weight;
		}
	}
	shadow_alpha /= total_weight;
	shadow_alpha *= shadow_enabled ? shadow_color.a : 0.0;
	// CanvasGroup's backbuffer contains premultiplied colors.
	float alpha = foreground.a + shadow_alpha * (1.0 - foreground.a);
	vec3 premultiplied = foreground.rgb
		+ shadow_color.rgb * shadow_alpha * (1.0 - foreground.a);
	COLOR *= vec4(alpha > 0.0001 ? premultiplied / alpha : vec3(0.0), alpha);
}

shader_type canvas_item;

uniform vec4 light_color : source_color;
uniform vec4 middle_color : source_color;
uniform vec4 dark_color : source_color;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (distance(pixel.rgb, vec3(247.0, 216.0, 165.0) / 255.0) < 0.01) {
		pixel.rgb = light_color.rgb;
	} else if (distance(pixel.rgb, vec3(230.0, 156.0, 33.0) / 255.0) < 0.01) {
		pixel.rgb = middle_color.rgb;
	} else if (distance(pixel.rgb, vec3(181.0, 49.0, 32.0) / 255.0) < 0.01) {
		pixel.rgb = dark_color.rgb;
	}
	COLOR = pixel * tint;
}

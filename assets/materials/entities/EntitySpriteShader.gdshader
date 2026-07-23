shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform bool hurt = false;
uniform bool flip_x = false;
uniform bool flip_y = false;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	if (flip_x) {
		UV.x = 1.0 - UV.x;
	}
	if (flip_y) {
		UV.y = 1.0 - UV.y;
	}
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 final_color = mix(tex_color.rgb, vec3(1.0), hurt ? 1.0 : 0.0);
	COLOR = vec4(final_color, tex_color.a * alpha);
}
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float show = step(UV.x, progress);
	COLOR = tex_color * show * alpha;
}

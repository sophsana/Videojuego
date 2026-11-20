shader_type canvas_item;

uniform float clip_bottom : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (UV.y > clip_bottom) {
		c.a = 0.0;
	}
	COLOR = c;
}

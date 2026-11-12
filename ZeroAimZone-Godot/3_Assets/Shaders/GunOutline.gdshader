shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.5, 1.0, 1.0); // blue
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.99) {
		vec2 texel = TEXTURE_PIXEL_SIZE * outline_width;
		float alpha = 0.0;
		alpha += texture(TEXTURE, UV + vec2(texel.x, 0)).a;
		alpha += texture(TEXTURE, UV + vec2(-texel.x, 0)).a;
		alpha += texture(TEXTURE, UV + vec2(0, texel.y)).a;
		alpha += texture(TEXTURE, UV + vec2(0, -texel.y)).a;
		if (alpha > 0.0) {
			col = outline_color;
		}
	}
	COLOR = col;
}
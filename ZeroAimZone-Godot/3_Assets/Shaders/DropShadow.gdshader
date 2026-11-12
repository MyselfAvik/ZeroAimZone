shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float blur_amount : hint_range(0.0, 10.0) = 2.5;

void fragment() {
	float alpha = 0.0;
	if (blur_amount > 0.0) {
		vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;
		alpha += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a * 0.0625;
		alpha += texture(TEXTURE, UV + vec2(0.0, -ps.y)).a * 0.125;
		alpha += texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a * 0.0625;
		alpha += texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a * 0.125;
		alpha += texture(TEXTURE, UV).a * 0.25;
		alpha += texture(TEXTURE, UV + vec2(ps.x, 0.0)).a * 0.125;
		alpha += texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a * 0.0625;
		alpha += texture(TEXTURE, UV + vec2(0.0, ps.y)).a * 0.125;
		alpha += texture(TEXTURE, UV + vec2(ps.x, ps.y)).a * 0.0625;
	} else {
		alpha = texture(TEXTURE, UV).a;
	}
	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a);
}

shader_type canvas_item;
uniform vec4 blinkColor: source_color;
uniform float blink_intensity = 0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color = mix(color, blinkColor, blink_intensity * color.a);
	COLOR = color;
}

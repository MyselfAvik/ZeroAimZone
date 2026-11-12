shader_type canvas_item;

uniform float min_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float max_brightness : hint_range(0.0, 2.0) = 1.25;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;

uniform vec4 color_a : source_color = vec4(1.0, 0.847, 0.2, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 0.2, 0.753);

uniform float color_strength : hint_range(0.0, 1.0) = 0.25;

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;

    float brightness = mix(
        min_brightness,
        max_brightness,
        pulse
    );

    vec3 color = mix(
        color_a.rgb,
        color_b.rgb,
        pulse
    );

    vec3 result = tex.rgb * brightness;

    result = mix(
        result,
        result * color,
        color_strength
    );

    COLOR = vec4(result, tex.a);
}

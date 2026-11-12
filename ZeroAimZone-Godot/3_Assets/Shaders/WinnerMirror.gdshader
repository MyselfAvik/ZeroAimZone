shader_type canvas_item;

uniform float shine_speed : hint_range(0.0, 5.0) = 1.0;
uniform float shine_width : hint_range(0.05, 1.0) = 0.25;
uniform float shine_strength : hint_range(0.0, 2.0) = 0.35;
uniform vec4 shine_color : source_color = vec4(1.0, 0.647, 0.0, 0.392);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Diagonal moving shine
    float position = UV.x + UV.y * 0.45;
    float movement = fract(TIME * shine_speed * 0.15);

    // Distance from moving shine
    float shine = 1.0 - smoothstep(
        0.0,
        shine_width,
        abs(position - movement)
    );

    // Make the shine fade naturally
    shine *= smoothstep(0.0, 0.15, position);
    shine *= smoothstep(1.2, 0.7, position);

    // Add golden light
    vec3 final_color = tex.rgb +
        shine_color.rgb * shine * shine_strength;

    COLOR = vec4(final_color, tex.a);
}

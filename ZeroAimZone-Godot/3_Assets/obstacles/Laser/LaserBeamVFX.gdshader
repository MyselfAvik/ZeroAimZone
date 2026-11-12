shader_type canvas_item;
render_mode blend_add;

uniform vec4 beam_color : source_color = vec4(1.0, 0.05, 0.05, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Glow and Core properties (Matching Image 3 Top reference)
uniform float glow_intensity : hint_range(0.2, 4.0) = 1.1;
uniform float glow_falloff : hint_range(1.0, 10.0) = 3.8;
uniform float core_intensity : hint_range(0.5, 5.0) = 2.2;
uniform float core_sharpness : hint_range(200.0, 2500.0) = 1200.0;

// Subtle animation
uniform float flicker_strength : hint_range(0.0, 0.3) = 0.03;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    float dist = abs(UV.y - 0.5) * 2.0; // 0.0 at center, 1.0 at outer edge

    // 1. Soft, misty, diffused Gaussian glow (gradual translucent fade-out)
    float edge_fade = 1.0 - smoothstep(0.65, 1.0, dist);
    float glow = exp(-dist * dist * glow_falloff) * edge_fade;

    // 2. Razor-thin crisp white center core needle
    float core = exp(-dist * dist * core_sharpness);

    // 3. Subtle organic breathing / flicker
    float pulse = 1.0 + 0.02 * sin(TIME * pulse_speed);
    float flicker = 1.0 - flicker_strength * sin(TIME * 15.0 + UV.x * 4.0);

    // 4. Color composition
    vec3 col = beam_color.rgb * COLOR.rgb * glow * glow_intensity * pulse;
    col += core_color.rgb * core * core_intensity * pulse;
    col *= flicker;

    // 5. Translucent alpha falloff
    float alpha = clamp(glow * glow_intensity * 0.75 + core * core_intensity, 0.0, 1.0) * COLOR.a;

    COLOR = vec4(col, alpha);
}
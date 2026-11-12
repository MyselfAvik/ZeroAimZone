shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    vec2 p = (UV * 2.0) - 1.0;
    vec3 gold = vec3(1.0, 0.87, 0.55);
    float edge_falloff = 1.0 - smoothstep(0.0, 1.4, max(abs(p.x), abs(p.y)));
    vec3 flash_col = mix(gold, vec3(1.0), edge_falloff * 0.6);

    // additive: keeps the art visible, brightens toward white at flash peak
    vec3 final_rgb = tex_color.rgb + flash_col * flash_amount;

    COLOR = vec4(final_rgb, tex_color.a);
}

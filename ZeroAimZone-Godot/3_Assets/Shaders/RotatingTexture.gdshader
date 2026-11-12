shader_type canvas_item;
// Additive blending keeps transparent or black texture backgrounds invisible
// while allowing the rays/sparkles themselves to brighten the artwork behind.
render_mode unshaded, blend_add;

// Assign the radial-rays texture to the TextureRect that uses this material.
// Place that TextureRect behind the chest/reward artwork.
uniform float rotation_speed : hint_range(0.0, 4.0, 0.01) = 0.55;
uniform float rotation_arc : hint_range(0.0, 3.14, 0.01) = 0.65;
uniform float counter_rotation_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float pulse_speed : hint_range(0.0, 10.0, 0.01) = 1.25;
uniform float pulse_amount : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float ray_brightness : hint_range(0.0, 4.0, 0.01) = 1.20;
uniform float center_glow_strength : hint_range(0.0, 2.0, 0.01) = 0.35;
uniform float center_glow_radius : hint_range(0.01, 1.0, 0.01) = 0.28;
uniform float edge_fade : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform vec4 ray_tint : source_color = vec4(0.72, 0.82, 1.0, 1.0);

vec2 rotate_uv(vec2 uv, float angle) {
	vec2 centered_uv = uv - vec2(0.5);
	float cosine = cos(angle);
	float sine = sin(angle);
	return vec2(
		centered_uv.x * cosine - centered_uv.y * sine,
		centered_uv.x * sine + centered_uv.y * cosine
	) + vec2(0.5);
}

void fragment() {
	// Oscillate around the UV midpoint, preserving the texture's centre while
	// it moves clockwise and then anti-clockwise.
	float primary_angle = sin(TIME * rotation_speed) * rotation_arc;
	vec4 primary_rays = texture(TEXTURE, rotate_uv(UV, primary_angle));

	// A faint opposite-moving layer gives the glow more depth.
	vec4 secondary_rays = texture(TEXTURE, rotate_uv(UV, -primary_angle));
	vec4 rays = mix(primary_rays, secondary_rays, counter_rotation_strength);

	float distance_from_center = length(UV - vec2(0.5));
	float radial_glow = 1.0 - smoothstep(0.0, center_glow_radius, distance_from_center);
	float safe_edge_fade = max(edge_fade, 0.001);
	float edge_mask = 1.0 - smoothstep(0.5 - safe_edge_fade, 0.5, distance_from_center);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	vec3 light = rays.rgb * ray_tint.rgb * ray_brightness * pulse;
	light += ray_tint.rgb * radial_glow * center_glow_strength * pulse;
	float alpha = rays.a * ray_tint.a * edge_mask;

	COLOR = vec4(light, alpha);
}

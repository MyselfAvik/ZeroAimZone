shader_type canvas_item;
render_mode blend_add; 

uniform vec3 effect_color : source_color = vec3(0.2, 0.6, 1.0);
uniform int octave_count : hint_range(1, 50) = 10;
uniform float amp_start = 0.5;
uniform float amp_coeff = 0.5;
uniform float freq_coeff = 2.0;
uniform float speed = 100.0;
uniform float bolt_width : hint_range(0.01, 5.0) = 2.0;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float edge_softness = 0.03;


uniform float glow_intensity : hint_range(1.0, 30.0) = 10.0;
uniform float flicker_min : hint_range(0.0, 1.0) = 0.6;
uniform float core_boost : hint_range(0.0, 3.0) = 1.5;

float hash12(vec2 x)
{
	return fract(cos(mod(dot(x, vec2(13.9898, 8.141)), 3.14)) * 43758.5453);
}
vec2 hash22(vec2 uv)
{
	uv = vec2(
		dot(uv, vec2(127.1, 311.7)),
		dot(uv, vec2(269.5, 183.3))
	);
	return 2.0 * fract(sin(uv) * 43758.5453123) - 1.0;
}
float noise(vec2 uv)
{
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	vec2 blur = smoothstep(vec2(0.0), vec2(1.0), fuv);
	return mix(
		mix(
			dot(hash22(iuv + vec2(0.0,0.0)), fuv - vec2(0.0,0.0)),
			dot(hash22(iuv + vec2(1.0,0.0)), fuv - vec2(1.0,0.0)),
			blur.x
		),
		mix(
			dot(hash22(iuv + vec2(0.0,1.0)), fuv - vec2(0.0,1.0)),
			dot(hash22(iuv + vec2(1.0,1.0)), fuv - vec2(1.0,1.0)),
			blur.x
		),
		blur.y
	) + 0.5;
}
float fbm(vec2 uv, int octaves)
{
	float value = 0.0;
	float amplitude = amp_start;
	for(int i = 0; i < octaves; i++)
	{
		value += amplitude * noise(uv);
		uv *= freq_coeff;
		amplitude *= amp_coeff;
	}
	return value;
}
void fragment()
{
    vec2 uv = 2.0 * UV - 1.0;

    uv += fbm(uv + TIME + speed, octave_count);
    float dist = abs(uv.x) / bolt_width;

    float flicker = mix(flicker_min, 1.0, hash12(vec2(TIME)));

    vec3 color = effect_color * glow_intensity * flicker / max(dist, 0.05);

    float core = smoothstep(0.2, 0.0, dist) * core_boost;
    color += vec3(core);

    float brightness = color.r + color.g + color.b;
    if (brightness < 0.05)
    {
        discard;
    }

    if (UV.x > progress)
    {
        discard;
    }

    float fade = smoothstep(progress - edge_softness, progress, UV.x);
    COLOR = vec4(color * (1.0 - fade), 1.0 - fade);
}
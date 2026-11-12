class_name PremiumCurrencyEffect
extends Node

enum CurrencyType { COIN, DIAMOND }
var currency_type: CurrencyType = CurrencyType.COIN

var target_control: Control
var original_pos: Vector2

var glow_rect: TextureRect
var particles: CPUParticles2D

var shine_material: ShaderMaterial
var shine_tween: Tween
var pulse_tween: Tween

const SHADER_CODE = """
shader_type canvas_item;

uniform float shine_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size;
uniform float is_coin = 1.0;

varying vec2 local_pos;

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec2 local_uv = local_pos / rect_size;
    
    // Diagonal line
    float pos = (local_uv.x * 1.5) + local_uv.y; 
    float center = mix(-0.5, 2.0, shine_progress);
    float dist = abs(pos - center);
    float shine = 1.0 - smoothstep(0.0, 0.2, dist);
    
    // Pixel-perfect geometric masking
    // Convert local_uv to a square space where the icon sits (left side)
    // rect_size.x / rect_size.y is the aspect ratio of the button
    vec2 pixel_uv = vec2(local_uv.x * (rect_size.x / rect_size.y), local_uv.y);
    
    // The icon is slightly padded, so its center is not exactly 0.5, 0.5. 
    // And its radius is smaller than the full half-height.
    vec2 icon_center = vec2(0.45, 0.5); 
    
    float shape_mask = 0.0;
    
    if (is_coin > 0.5) {
        // Coin: Circle mask (tighter radius of 0.35 instead of 0.45)
        float d = distance(pixel_uv, icon_center);
        shape_mask = 1.0 - smoothstep(0.32, 0.35, d);
    } else {
        // Diamond: Rhombus mask (tighter radius)
        vec2 p = abs(pixel_uv - icon_center);
        float d = p.x + p.y;
        shape_mask = 1.0 - smoothstep(0.32, 0.35, d);
    }
    
    shine *= shape_mask;
    
    color.rgb += shine * color.a * 0.7;
    COLOR = color;
}
"""

func _ready() -> void:
	var currency_button := get_parent() as Control
	if not currency_button:
		return

	# Currency buttons hold their visible coin/diamond in a child TextureRect.
	# Apply the shader to that icon, not the transparent button background.
	target_control = _find_currency_icon(currency_button)
	if target_control == null:
		target_control = currency_button
		
	if "coin" in target_control.name.to_lower():
		currency_type = CurrencyType.COIN
	else:
		currency_type = CurrencyType.DIAMOND
		
	# Wait for layout to settle before capturing position
	await get_tree().process_frame
	original_pos = target_control.position
	
	_setup_glow()
	_setup_particles()
	_setup_shader()
	
	_start_animations()


func _find_currency_icon(currency_button: Control) -> TextureRect:
	for child in currency_button.get_children():
		if child is TextureRect:
			var child_name := child.name.to_lower()
			if "coin" in child_name or "diamond" in child_name:
				return child as TextureRect
	return null
	
func _setup_glow() -> void:
	glow_rect = TextureRect.new()
	glow_rect.name = "PremiumGlow"
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.5, Color(1, 1, 1, 0.5))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 1)
	tex.width = 128
	tex.height = 128
	
	glow_rect.texture = tex
	glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Icon is likely a square on the left, so use height for size
	var icon_size = target_control.size.y
	glow_rect.custom_minimum_size = Vector2(icon_size, icon_size) * 1.5
	
	# Center it behind the icon (left side)
	var icon_center = Vector2(icon_size / 2.0, icon_size / 2.0)
	glow_rect.position = icon_center - (glow_rect.custom_minimum_size / 2.0)
	glow_rect.pivot_offset = glow_rect.custom_minimum_size / 2.0
	
	if currency_type == CurrencyType.COIN:
		glow_rect.modulate = Color(1.0, 0.8, 0.2, 0.6) # Golden
	else:
		glow_rect.modulate = Color(0.4, 0.8, 1.0, 0.6) # Blue/White
		
	glow_rect.z_index = -1
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_control.add_child(glow_rect)
	target_control.move_child(glow_rect, 0)

func _setup_particles() -> void:
	particles = CPUParticles2D.new()
	particles.name = "PremiumSparkles"
	particles.amount = 3
	particles.lifetime = 2.0
	particles.randomness = 1.0
	
	var icon_size = target_control.size.y
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(icon_size, icon_size) / 2.0
	particles.position = Vector2(icon_size / 2.0, icon_size / 2.0)
	
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.gravity = Vector2(0, -10)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	
	var gradient = Gradient.new()
	if currency_type == CurrencyType.COIN:
		gradient.colors = PackedColorArray([Color(1, 0.8, 0, 0), Color(1, 1, 0.8, 1), Color(1, 0.8, 0, 0)])
	else:
		gradient.colors = PackedColorArray([Color(0.5, 0.8, 1, 0), Color(0.8, 0.9, 1, 1), Color(0.5, 0.8, 1, 0)])
	
	particles.color_ramp = gradient
	target_control.add_child(particles)

func _setup_shader() -> void:
	var shader = Shader.new()
	shader.code = SHADER_CODE
	shine_material = ShaderMaterial.new()
	shine_material.shader = shader
	shine_material.set_shader_parameter("rect_size", target_control.size)
	shine_material.set_shader_parameter("is_coin", 1.0 if currency_type == CurrencyType.COIN else 0.0)
	target_control.material = shine_material

func _start_animations() -> void:
	# 1. Pulse Glow
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(glow_rect, "scale", Vector2(1.1, 1.1), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.parallel().tween_property(glow_rect, "modulate:a", 0.8, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(glow_rect, "scale", Vector2(0.95, 0.95), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.parallel().tween_property(glow_rect, "modulate:a", 0.4, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	

	# 3. Shine Sweep
	shine_tween = create_tween().set_loops()
	shine_tween.tween_interval(4.0) # Wait 4 seconds
	shine_tween.tween_method(_set_shine_progress, 0.0, 1.0, 1.0) # Sweep takes 1 second
	shine_tween.tween_interval(1.0) # Random wait before next loop

func _set_shine_progress(val: float) -> void:
	if shine_material:
		shine_material.set_shader_parameter("shine_progress", val)

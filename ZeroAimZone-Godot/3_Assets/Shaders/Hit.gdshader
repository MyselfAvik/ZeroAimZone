shader_type canvas_item;
render_mode blend_add; 

uniform float x_scale = 0.5;
uniform float y_scale = 1.0;

void vertex() {
    VERTEX.x *= x_scale;
    VERTEX.y *= y_scale;
}
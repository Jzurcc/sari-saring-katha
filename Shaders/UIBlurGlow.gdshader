shader_type canvas_item;
render_mode blend_add;

uniform float blur_radius : hint_range(0.0, 30.0) = 8.0; 
uniform int iterations : hint_range(1, 64) = 32; 

void fragment() {
    vec2 uv = SCREEN_UV; 
    vec4 color = texture(TEXTURE, UV);
    float total_weight = 1.0;
    
    float radius = blur_radius * 0.001; 
    float angle = 2.39996323;

    for (int i = 1; i <= iterations; i++) {
        float r = radius * sqrt(float(i));
        float a = angle * float(i);
        vec2 offset = vec2(cos(a), sin(a)) * r;
        
        color += texture(TEXTURE, UV + offset);
        total_weight += 1.0;
    }

    COLOR = color / total_weight;
}

shader_type spatial;
render_mode depth_prepass_alpha, cull_back, unshaded;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // Only draw outline pixels: transparent pixels adjacent to opaque ones.
    // Opaque pixels are skipped so we don't overdraw the base sprite.
    if (tex.a > 0.01) {
        discard;
    }

    float max_a = 0.0;
    max_a = max(max_a, texture(albedo_texture, UV + vec2(outline_width, 0.0)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(-outline_width, 0.0)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(0.0, outline_width)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(0.0, -outline_width)).a);

    if (max_a > 0.01) {
        ALBEDO = outline_color.rgb;
        ALPHA = outline_color.a * 0.8;
    } else {
        discard;
    }
}

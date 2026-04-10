shader_type spatial;
render_mode depth_draw_never, cull_back, unshaded, shadows_disabled;

uniform float z_roll_rad = 0.0;

void vertex() {
	// Replicate Sprite3D Spherical Billboarding while keeping original scale intact
	mat4 mat_world = mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz) * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz) * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz) * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);

	// Apply Z rotation to match the Sprite3D's specific tilt
	float c = cos(z_roll_rad);
	float s = sin(z_roll_rad);
	mat4 rot_z = mat4(
		vec4(c, s, 0.0, 0.0),
		vec4(-s, c, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);

	MODELVIEW_MATRIX = VIEW_MATRIX * (mat_world * rot_z);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Width in PIXELS — converted to UV space per-axis via textureSize so
// left/right and top/bottom are always equal thickness on non-square textures.
uniform float outline_width : hint_range(0.0, 20.0) = 8.0;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // Only draw on transparent pixels adjacent to the sprite's opaque area.
    if (tex.a > 0.01) {
        discard;
    }

    // Convert pixel-width to per-axis UV step (fixes non-square texture stretch).
    vec2 px = vec2(outline_width) / vec2(textureSize(albedo_texture, 0));

    // 8-direction sampling: 4 cardinal + 4 diagonal → smooth corners.
    float max_a = 0.0;
    max_a = max(max_a, texture(albedo_texture, UV + vec2( px.x,    0.0)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(-px.x,    0.0)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(   0.0,  px.y)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(   0.0, -px.y)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2( px.x,  px.y)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(-px.x,  px.y)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2( px.x, -px.y)).a);
    max_a = max(max_a, texture(albedo_texture, UV + vec2(-px.x, -px.y)).a);

    if (max_a > 0.01) {
        ALBEDO = outline_color.rgb;
        ALPHA  = outline_color.a * 0.8;
    } else {
        discard;
    }
}

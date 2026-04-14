shader_type spatial;
render_mode depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Width in PIXELS — converted to UV space per-axis via textureSize so
// left/right and top/bottom are always equal thickness on non-square textures.
uniform float outline_width : hint_range(0.0, 40.0) = 16.0;
// Enable Fixed-Y billboard (rotate around world Y only) to match Sprite3D
// billboard = 2. Leave false for items that need full camera-facing billboard.
uniform bool fixed_y_billboard = false;

void vertex() {
	vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);

	mat4 mat_world;
	if (fixed_y_billboard) {
		// Rotate around the world Y axis only — matches Sprite3D billboard = 2.
		// Camera right projected flat onto the XZ plane, world up stays (0,1,0).
		vec3 cam_x  = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
		vec3 world_y = vec3(0.0, 1.0, 0.0);
		vec3 cam_z  = normalize(cross(cam_x, world_y));
		mat_world = mat4(
			vec4(cam_x   * scale.x, 0.0),
			vec4(world_y * scale.y, 0.0),
			vec4(cam_z   * scale.z, 0.0),
			MODEL_MATRIX[3]
		);
	} else {
		// Full billboard — face the camera on both axes (used for items).
		mat_world = mat4(
			vec4(normalize(INV_VIEW_MATRIX[0].xyz) * scale.x, 0.0),
			vec4(normalize(INV_VIEW_MATRIX[1].xyz) * scale.y, 0.0),
			vec4(normalize(INV_VIEW_MATRIX[2].xyz) * scale.z, 0.0),
			MODEL_MATRIX[3]
		);
	}

	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float safe_alpha(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

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
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2( px.x,    0.0)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2(-px.x,    0.0)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2(   0.0,  px.y)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2(   0.0, -px.y)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2( px.x,  px.y)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2(-px.x,  px.y)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2( px.x, -px.y)));
	max_a = max(max_a, safe_alpha(albedo_texture, UV + vec2(-px.x, -px.y)));

	if (max_a > 0.01) {
		ALBEDO = outline_color.rgb;
		ALPHA  = outline_color.a;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		discard;
	}
}

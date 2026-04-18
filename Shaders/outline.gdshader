shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color;
uniform float outline_width = 4.0;

void vertex() {
	// Expand the vertex in object space so the outline stays perfectly glued to the model
	// regardless of how far away the camera gets. The multiplier scales the existing
	// 4.0 - 16.0 values down to a physical thickness.
	VERTEX += NORMAL * (outline_width * 0.002);
	
	// Standard clip-space projection
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	ALBEDO = outline_color.rgb * 0.9;
	if (outline_color.a < 1.0) {
		ALPHA = outline_color.a;
	}
}

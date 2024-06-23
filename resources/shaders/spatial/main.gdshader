shader_type spatial;
render_mode unshaded;

uniform uint frame;
uniform sampler2D render_texture : source_color, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 tex_col = texture(render_texture, SCREEN_UV);
	vec3 col = tex_col.rgb / float(frame + 1U);
	//col = mix(pow((col + 0.055) * (1.0 / (1.0 + 0.055)), vec3(2.4)), col * (1.0 / 12.92), lessThan(col, vec3(0.04045))); // SRGB -> Linear
	ALBEDO = col;
}
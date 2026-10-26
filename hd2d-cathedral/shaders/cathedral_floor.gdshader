shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D floor_texture : source_color, filter_linear_mipmap;
void fragment() {
	// Trim the transparent export margins in UV space, without altering the asset.
	vec2 uv = vec2(mix(0.055, 0.945, UV.x), mix(0.035, 0.965, fract(UV.y * 1.6)));
	if (UV.x < 0.41) {
		uv.x = mix(0.065, 0.37, fract(UV.x / 0.41 * 3.0));
		uv.y = mix(0.04, 0.96, fract(UV.y * 4.8));
	} else if (UV.x > 0.59) {
		uv.x = mix(0.63, 0.935, fract((UV.x - 0.59) / 0.41 * 3.0));
		uv.y = mix(0.04, 0.96, fract(UV.y * 4.8));
	} else {
		uv.x = mix(0.4, 0.6, (UV.x - 0.41) / 0.18);
	}
	vec3 stone = texture(floor_texture, uv).rgb;
	float pool = exp(-pow((UV.x - 0.5) * 5.0, 2.0));
	ALBEDO = stone * mix(vec3(0.58, 0.51, 0.43), vec3(1.04, 0.94, 0.77), pool);
}

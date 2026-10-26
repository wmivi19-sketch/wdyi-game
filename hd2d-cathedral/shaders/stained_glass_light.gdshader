shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D glass_texture : source_color, filter_linear_mipmap;
void fragment() {
	vec2 uv = vec2(mix(0.29, 0.71, UV.x), mix(0.07, 0.94, UV.y));
	vec4 glass = texture(glass_texture, uv);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, 1.0-UV.x);
	edge *= smoothstep(0.0, 0.08, UV.y) * smoothstep(0.0, 0.12, 1.0-UV.y);
	ALBEDO = glass.rgb * glass.rgb * 0.8;
	ALPHA = glass.a * edge * 0.18;
}

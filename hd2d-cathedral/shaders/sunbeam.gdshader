shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 beam_color : source_color = vec4(1.0, 0.79, 0.44, 0.12);
void fragment() {
	float edge = pow(max(sin(UV.x * 3.14159265), 0.0), 2.0);
	float fade = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	float streak = 0.8 + 0.2 * sin(UV.x * 73.0);
	ALBEDO = beam_color.rgb;
	ALPHA = edge * fade * streak * beam_color.a;
}

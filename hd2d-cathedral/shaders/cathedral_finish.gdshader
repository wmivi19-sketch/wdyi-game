shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 original = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 glow = max(textureLod(screen_texture, SCREEN_UV, 3.0).rgb - vec3(0.66), vec3(0.0));
	vec2 center = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float vignette = smoothstep(0.20, 0.64, length(center));
	COLOR = vec4((original + glow * 0.23) * (1.0 - 0.29 * vignette), 1.0);
}

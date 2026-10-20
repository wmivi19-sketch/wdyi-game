shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent : source_color = vec4(1.0, 0.1, 0.22, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float motion : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    // Slanted parallelogram; the empty area stays truly transparent.
    float x = (uv.x - 0.045 * (1.0 - uv.y)) / 0.955;
    float shape = step(0.0, x) * step(x, 1.0);
    float edge = max(step(x, 0.008), step(0.992, x));
    edge = max(edge, max(step(uv.y, 0.06), step(0.94, uv.y)));
    float wave = sin(uv.y * 13.0 + TIME * 5.0 * motion) * 0.007 * motion;
    float liquid = step(x, clamp(fill + wave * sin(fill * 3.14159), 0.0, 1.0));
    liquid *= step(0.00001, fill);
    float ghost = step(x, trail) * step(0.00001, trail);
    vec3 color = mix(vec3(0.035, 0.045, 0.075), accent.rgb * 0.45, ghost);
    vec3 gradient = accent.rgb * mix(0.55, 1.15, 1.0 - uv.y);
    float gleam = pow(max(0.0, sin(x * 12.0 - TIME * 2.3 * motion)), 20.0);
    gradient += vec3(0.3) * gleam * motion;
    color = mix(color, gradient, liquid);
    float pulse = (0.5 + 0.5 * sin(TIME * 9.0)) * motion;
    // Warning stays visible even with zero fill or reduced motion.
    color = mix(color, accent.rgb * 0.24, danger * (0.3 + pulse * 0.25));
    color = mix(color, vec3(1.0, 0.85, 0.8), danger * pulse * liquid * 0.45);
    vec3 border = mix(vec3(0.9, 0.93, 1.0), accent.rgb, danger * (0.4 + pulse * 0.6));
    color = mix(color, border, edge * 0.8);
    COLOR = vec4(color, shape);
}

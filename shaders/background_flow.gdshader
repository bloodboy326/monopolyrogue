shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.025, 0.035, 0.09, 1.0);
uniform vec4 color_b : source_color = vec4(0.06, 0.015, 0.10, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 pulse_color : source_color = vec4(1.0, 0.18, 0.72, 1.0);
uniform float grid_scale = 26.0;

float line_grid(vec2 p) {
	vec2 g = abs(fract(p) - 0.5);
	float line = min(g.x, g.y);
	return 1.0 - smoothstep(0.012, 0.035, line);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float wave = sin((uv.x * 2.4 + uv.y * 4.2 + TIME * 0.22) * 6.28318) * 0.5 + 0.5;
	vec4 base = mix(color_a, color_b, uv.y + wave * 0.16);
	float grid = line_grid((uv + vec2(TIME * 0.018, -TIME * 0.012)) * vec2(grid_scale, grid_scale * 0.58));
	float scan = sin((uv.y + TIME * 0.35) * 720.0) * 0.035;
	float vignette = smoothstep(0.92, 0.18, distance(uv, vec2(0.5)));
	float speckle = hash(floor((uv + TIME * 0.01) * 260.0)) * 0.045;
	base.rgb += grid_color.rgb * grid * 0.13;
	base.rgb += pulse_color.rgb * pow(wave, 5.0) * 0.08;
	base.rgb += scan + speckle;
	base.rgb *= 0.78 + vignette * 0.42;
	COLOR = base;
}

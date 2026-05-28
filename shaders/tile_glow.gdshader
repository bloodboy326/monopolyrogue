shader_type canvas_item;

uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.95, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float edge = 1.0 - smoothstep(0.0, 0.22, min(edge_x, edge_y));
	float ripple = sin((UV.x + UV.y + TIME * 2.8) * 18.0) * 0.5 + 0.5;
	tex.rgb += glow_color.rgb * glow * (edge * 0.9 + ripple * 0.12);
	tex.a = max(tex.a, glow * edge * 0.35);
	COLOR = tex;
}

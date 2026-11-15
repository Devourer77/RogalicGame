// Подсветка клетки: слабая заливка + яркий контур по краю соты.
// Плиты под подсветкой остаются видны, а сама подсветка читается по контуру.
// color.a задаёт силу подсветки (как раньше у сплошной заливки).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.6, 1.0, 0.35);
uniform float apothem = 0.5;          // расстояние от центра до середины стороны соты, м
uniform float fill_part = 0.45;       // доля заливки от color.a
uniform float edge_width = 0.09;      // ширина контура, м
uniform float edge_boost = 1.35;      // контур ярче самого цвета

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// «расстояние» до края шестиугольника (углы на ±Z, стороны на ±X): 1 — на краю
	vec2 p = abs(local_pos.xz);
	float f = max(p.x, p.x * 0.5 + p.y * 0.8660254) / apothem;
	float edge = smoothstep(1.0 - edge_width / apothem * 1.6, 1.0 - edge_width / apothem * 0.4, f);
	vec3 c = mix(color.rgb, min(color.rgb * edge_boost + 0.08, vec3(1.0)), edge);
	ALBEDO = c;
	ALPHA = clamp(color.a * mix(fill_part, 2.2, edge), 0.0, 1.0);
}

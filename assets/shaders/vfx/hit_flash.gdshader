// Вспышка модели при уроне. Кладётся поверх всех материалов модели (material_overlay)
// и просто подмешивает цвет: amount = 1 — модель вся светится, 0 — вспышки нет.
// Края модели светятся сильнее (френель), поэтому силуэт читается даже у светлых врагов.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = flash_color.rgb * amount * (0.55 + 0.9 * fresnel);
}

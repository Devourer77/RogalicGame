// Вспышка модели при уроне. Кладётся поверх всех материалов модели (material_overlay)
// и просто подмешивает цвет: amount = 1 — модель вся светится, 0 — вспышки нет.
// Края модели светятся сильнее (френель), поэтому силуэт читается даже у светлых врагов.
// Ещё здесь постоянный «контровой свет»: тонкая светлая кайма по контуру фигурки
// (rim_strength), чтобы фигурки отделялись от плит. Светит всегда, даже без вспышки.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.72, 0.86, 0.95, 1.0);   // холодный, как лунный свет
uniform float rim_strength : hint_range(0.0, 2.0) = 0.38;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;   // больше — кайма тоньше

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = flash_color.rgb * amount * (0.55 + 0.9 * fresnel) + rim_color.rgb * rim * rim_strength;
}

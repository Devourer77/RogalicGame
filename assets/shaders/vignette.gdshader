// Виньетка: края экрана мягко темнеют, центр не трогается.
// Висит на ColorRect во весь экран (battle.gd, _add_vignette).
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.45;   // насколько темнеют углы
uniform float inner : hint_range(0.0, 1.0) = 0.45;      // до какого радиуса темноты нет
uniform vec3 tint : source_color = vec3(0.02, 0.04, 0.035);   // цвет сумрака (в тон туману)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.25;   // экран шире, чем выше — круг слегка растянут
	float d = length(p) / 1.6;
	float a = smoothstep(inner, 1.0, d) * strength;
	COLOR = vec4(tint, a);
}

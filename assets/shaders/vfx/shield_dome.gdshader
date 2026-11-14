// Купол щита: прозрачный в середине, светится по краю (френель) и бегущими волнами.
// amount — общая яркость (VfxPlayer гасит её к концу), color — цвет щита.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.9, 0.75, 0.35, 1.0);
uniform float amount : hint_range(0.0, 2.0) = 1.0;
uniform float energy = 2.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	// Бегущие снизу вверх полосы — купол «дышит»
	float bands = 0.5 + 0.5 * sin(local_pos.y * 18.0 - TIME * 6.0);
	// Низ купола у земли растворяется, чтобы не было резкого края на плитах
	float base_fade = smoothstep(0.0, 0.15, local_pos.y);
	float a = (fresnel * 0.9 + bands * 0.12 + 0.04) * base_fade * amount;
	ALBEDO = color.rgb * energy * a;
}

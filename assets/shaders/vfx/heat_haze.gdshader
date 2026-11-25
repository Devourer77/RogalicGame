shader_type spatial;
// Марево над лавой: полоса, повёрнутая к камере (вокруг вертикали), искажает то, что за ней.
// Без цвета — только дрожание картинки и чуть тёплый отсвет. Кладёт VfxPlayer.heat_haze.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.006;     // насколько сдвигается картинка (доля экрана)
uniform float speed = 1.6;          // как быстро дрожит
uniform vec3 tint = vec3(1.0, 0.82, 0.6);   // лёгкий тёплый оттенок
uniform float tint_amount = 0.06;
instance uniform float phase = 0.0;  // у каждой клетки свой сдвиг узора

void vertex() {
	// Поворот к камере только вокруг вертикали (как BILLBOARD_FIXED_Y)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// Маска: мягкий овал, внизу (у лавы) сильнее, к верху гаснет
	vec2 c = UV - vec2(0.5, 0.55);
	float oval = 1.0 - smoothstep(0.15, 0.5, length(c * vec2(1.0, 0.8)));
	float mask = oval * mix(0.4, 1.0, UV.y);
	// Волны поднимаются вверх: несколько синусов разной частоты вместо текстуры шума
	float t = TIME * speed + phase;
	float wx = sin(UV.y * 23.0 + t * 3.1) + 0.6 * sin(UV.y * 41.0 - t * 4.3 + UV.x * 7.0);
	float wy = sin(UV.x * 19.0 + t * 2.3) * 0.5;
	vec2 offset = vec2(wx, wy) * strength * mask;
	vec3 col = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;
	ALBEDO = mix(col, col * tint * 1.25, tint_amount * mask);
	ALPHA = clamp(mask * 1.2, 0.0, 1.0);
}

// Состояния на самой модели фигурки: мокрый, яд, опутан (тина).
// Кладётся вторым проходом поверх материалов модели (next_pass у слоя вспышки урона),
// поэтому модели не нужен особый материал — работает с любой.
// Частицы состояний (капли, пузырьки, кольца) рисует VfxPlayer, этот слой их дополняет.
//
// Узор берётся из второго UV-слоя (RestUV: обхват и высота в позе покоя, его кладёт stylize.py),
// поэтому прожилки яда и тина не «плывут» по телу во время анимации.
// У моделей без RestUV узор строится по позиции точки — тоже работает, но может слегка ползти.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, diffuse_burley, specular_schlick_ggx;

uniform float wet : hint_range(0.0, 1.0) = 0.0;      // мокрый: тёмная блестящая плёнка, сильнее внизу
uniform float poison : hint_range(0.0, 1.0) = 0.0;   // яд: светящиеся зелёные прожилки, пульсируют
uniform float bound : hint_range(0.0, 1.0) = 0.0;    // опутан: тина поднимается от ног
uniform float height = 1.6;                          // рост модели, м (для моделей без RestUV)

uniform vec3 poison_color : source_color = vec3(0.45, 0.95, 0.30);
uniform vec3 slime_color : source_color = vec3(0.17, 0.22, 0.11);

varying vec2 rest;
varying vec3 local_pos;

float hash(vec2 p, float period) {
	p.x = mod(p.x, period);   // по обхвату узор замкнут, без шва на спине
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i, period);
	float b = hash(i + vec2(1.0, 0.0), period);
	float c = hash(i + vec2(0.0, 1.0), period);
	float d = hash(i + vec2(1.0, 1.0), period);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	rest = UV2;
	local_pos = VERTEX;
}

void fragment() {
	if (wet + poison + bound < 0.001) {
		discard;
	}
	bool has_rest = rest.x + rest.y > 0.0001;
	// u — обхват 0..1, v — высота 0..1
	float u = has_rest ? rest.x : atan(local_pos.x, local_pos.z) / 6.2832 + 0.5;
	float v = has_rest ? 1.0 - rest.y : clamp(local_pos.y / height, 0.0, 1.0);   // glTF переворачивает V

	vec3 col = vec3(0.0);
	float alpha = 0.0;
	float rough = 0.5;
	vec3 glow = vec3(0.0);

	// Мокрый: тёмная плёнка с блеском, внизу плотнее, сверху вниз сползают потёки
	if (wet > 0.001) {
		float streak = noise(vec2(u * 24.0, v * 2.5 + TIME * 0.35), 24.0);
		float a = wet * (0.30 + 0.22 * (1.0 - v) + 0.12 * smoothstep(0.55, 0.85, streak));
		col = mix(col, vec3(0.03, 0.05, 0.06), a);
		alpha = max(alpha, a);
		rough = 0.10;
	}

	// Опутан: тина от ног, с рваным краем; край чуть колышется
	if (bound > 0.001) {
		float n = noise(vec2(u * 14.0, v * 10.0), 14.0);
		float n2 = noise(vec2(u * 40.0, v * 30.0), 40.0);
		float edge = bound * 0.22 + (n - 0.5) * 0.16 + (n2 - 0.5) * 0.05 + sin(TIME * 1.7 + u * 25.0) * 0.008;
		float m = 1.0 - smoothstep(edge - 0.025, edge + 0.01, v);
		vec3 slime = mix(slime_color * 0.65, slime_color * 1.3, n2);
		col = mix(col, slime, m);
		alpha = max(alpha, m * 0.92);
		rough = mix(rough, 0.30, m);
	}

	// Яд: тонкие прожилки (гребни шума), по ним бежит пульс снизу вверх
	if (poison > 0.001) {
		float n = noise(vec2(u * 9.0, v * 5.0), 9.0) * 0.7 + noise(vec2(u * 24.0, v * 13.0), 24.0) * 0.3;
		float ridge = 1.0 - abs(n * 2.0 - 1.0);
		float vein = smoothstep(0.93, 0.985, ridge) * poison;
		float pulse = 0.55 + 0.45 * sin(TIME * 3.2 - v * 9.0);
		col = mix(col, poison_color * 0.6, vein);
		alpha = max(alpha, vein * 0.95);
		alpha = max(alpha, poison * 0.10);   // общий болезненный оттенок
		col = mix(col, poison_color * 0.35, poison * 0.10 * (1.0 - vein));
		glow += poison_color * vein * pulse * 0.9;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.6;
	EMISSION = glow;
	ALPHA = clamp(alpha, 0.0, 1.0);
}

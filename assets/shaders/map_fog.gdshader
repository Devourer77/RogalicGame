shader_type canvas_item;
// Туман карты пути: плывущие серые клубы закрывают всё выше границы видимости (fog_edge, доля высоты
// сверху вниз). Ниже границы — прозрачно; переход мягкий (softness). Клубы — шум fbm, медленно плывут.

uniform float fog_edge : hint_range(0.0, 1.0) = 0.4;    // граница тумана: выше неё (меньше y) — туман
uniform float softness : hint_range(0.01, 0.5) = 0.09;  // ширина мягкого края
uniform vec4 fog_color : source_color = vec4(0.42, 0.45, 0.44, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.82;    // насколько плотно закрывает в глубине тумана
uniform float speed = 0.012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float clouds = fbm(vec2(uv.x * 4.0 + t * 3.0, uv.y * 7.0 - t)) * 0.6 + fbm(vec2(uv.x * 9.0 - t * 5.0, uv.y * 12.0)) * 0.4;
	// граница рваная: клубы заходят ниже и выше на пару процентов
	float edge = fog_edge + (clouds - 0.5) * 0.06;
	float cover = 1.0 - smoothstep(edge - softness, edge + softness * 0.4, uv.y);
	float depth = 1.0 - smoothstep(edge - 0.25, edge, uv.y);   // глубже в тумане — плотнее
	float a = cover * mix(0.55, density, depth) * (0.75 + clouds * 0.45);
	COLOR = vec4(fog_color.rgb * (0.85 + clouds * 0.3), clamp(a, 0.0, 0.95));
}

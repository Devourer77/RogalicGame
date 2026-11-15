// Стоячая болотная вода и лужи: тёмная гладь с мелкой медленной рябью.
// Отражает небо (sky_reflect.gdshader) и арену (ReflectionProbe в battle.gd).
// Сбоку (под острым углом) вода отражает сильнее, прямо сверху — темнее и видна «глубина».
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.03, 0.05, 0.045);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.1, 0.09);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec3 glow_color : source_color = vec3(0.0);   // слабое свечение стихии (у луж — голубое)
uniform float glow_energy = 0.0;
uniform float ripple_scale = 1.1;     // размер ряби (больше — мельче)
uniform float ripple_strength = 0.12;
uniform float ripple_speed = 0.12;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.12;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// высота ряби: два слоя шума, плывут в разные стороны
float height(vec2 p) {
	float t = TIME * ripple_speed;
	return noise(p * ripple_scale + vec2(t, t * 0.6)) * 0.6
			+ noise(p * ripple_scale * 2.3 - vec2(t * 0.8, -t)) * 0.4;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// нормаль ряби из наклона высоты (по мировым X и Z, поэтому вода бесшовная)
	float e = 0.05;
	float h0 = height(world_pos.xz);
	float hx = height(world_pos.xz + vec2(e, 0.0));
	float hz = height(world_pos.xz + vec2(0.0, e));
	vec3 n = normalize(vec3((h0 - hx) * ripple_strength / e, 1.0, (h0 - hz) * ripple_strength / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(shallow_color, deep_color, facing);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = glow_color * glow_energy;
	ALPHA = alpha;
}

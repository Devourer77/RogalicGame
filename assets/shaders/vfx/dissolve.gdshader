// Растворение модели при смерти врага: тело «сгорает» пятнами по шуму,
// по краю дыр светится полоска (бирюза у тварей Раскола, пепел у Культа).
// Шум считается по положению точки в мире, поэтому развёртка (UV) модели не нужна.
// Цвет и свечение берутся из старого материала модели (см. VfxPlayer.dissolve).
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_vertex_color = false;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

uniform float progress : hint_range(0.0, 1.0) = 0.0;   // 0 — целый, 1 — исчез
uniform vec3 edge_color : source_color = vec3(0.37, 0.92, 0.83);
uniform float edge_width = 0.08;
uniform float edge_energy = 4.0;
uniform float noise_scale = 3.5;
uniform float base_y = 0.0;      // высота ног в мире: снизу растворяется позже
uniform float height = 1.6;      // рост фигурки

varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise3(world_pos * noise_scale) * 0.65 + noise3(world_pos * noise_scale * 2.3) * 0.35;
	// Голова уходит первой, ноги последними
	float h = clamp((world_pos.y - base_y) / max(height, 0.1), 0.0, 1.0);
	float v = n * 0.7 + (1.0 - h) * 0.3;
	float cut = progress * 1.15 - 0.05;
	if (v < cut) {
		discard;
	}
	vec4 tex = texture(albedo_texture, UV);
	vec3 base = albedo.rgb * tex.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;
	ROUGHNESS = roughness;
	float edge = 1.0 - smoothstep(0.0, edge_width, v - cut);
	EMISSION = emission_color * emission_energy + edge_color * edge * edge_energy * step(0.001, progress);
}

// Стелющийся туман: низкий слой над водой, медленно плывёт клочьями.
// Над самим полем почти прозрачный (бой должен читаться), гуще у краёв островка и над водой.
// Где касается предметов (берег, камни, декор) — мягко тает, без резкой линии.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 mist_color : source_color = vec3(0.32, 0.42, 0.4);
uniform float density : hint_range(0.0, 1.0) = 0.55;     // насколько густой у краёв
uniform float over_field : hint_range(0.0, 1.0) = 0.08;  // доля густоты над полем
uniform vec4 field_rect = vec4(0.0, 0.0, 14.0, 12.0);    // поле в мире: x_min, z_min, x_max, z_max
uniform float edge_fade = 2.2;   // за сколько метров от края поля туман набирает густоту
uniform float speed = 0.05;
uniform float scale = 0.18;      // размер клочьев (меньше — крупнее)
uniform float soft_depth = 0.5;  // мягкость касания с предметами, м
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float t = TIME * speed;
	float n = noise(p + vec2(t, t * 0.4)) * 0.55 + noise(p * 2.3 - vec2(t * 1.3, -t * 0.7)) * 0.3
			+ noise(p * 5.1 + vec2(t * 2.0, 0.0)) * 0.15;
	float clumps = smoothstep(0.35, 0.8, n);

	// расстояние от края поля наружу (внутри поля — 0)
	float dx = max(max(field_rect.x - world_pos.x, world_pos.x - field_rect.z), 0.0);
	float dz = max(max(field_rect.y - world_pos.z, world_pos.z - field_rect.w), 0.0);
	float outside = smoothstep(0.0, edge_fade, max(dx, dz));
	float amount = mix(over_field, 1.0, outside) * density * clumps;

	// мягкое касание с геометрией под туманом
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float scene_z = -view.z / view.w;
	float soft = clamp((scene_z - (-VERTEX.z)) / soft_depth, 0.0, 1.0);

	ALBEDO = mist_color;
	ALPHA = amount * soft;
}

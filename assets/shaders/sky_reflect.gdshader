// Небо только для отражений: в кадре его не видно (фон боя — ровный цвет),
// но блестящие поверхности (вода, лужи, лёд, сталь, мокрое) отражают его.
// Тёмное серо-зелёное небо, светлее к горизонту, бледное пятно луны со стороны солнца
// и тонкая бирюзовая трещина Раскола. Красного нет.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.02, 0.035, 0.035);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.24, 0.22);   // в тон туману
uniform vec3 ground_color : source_color = vec3(0.03, 0.045, 0.04);
uniform vec3 moon_color : source_color = vec3(0.75, 0.86, 0.92);
uniform float moon_size : hint_range(0.0, 1.0) = 0.06;
uniform vec3 rift_color : source_color = vec3(0.25, 0.9, 0.8);
uniform float rift_strength : hint_range(0.0, 4.0) = 1.2;

void sky() {
	vec3 d = EYEDIR;
	float up = d.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.6, up));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, up));
	// луна — со стороны солнца (первый направленный свет сцены)
	if (LIGHT0_ENABLED) {
		float m = dot(d, LIGHT0_DIRECTION);
		col += moon_color * smoothstep(1.0 - moon_size * 0.15, 1.0, m) * 2.0;   // диск
		col += moon_color * pow(max(m, 0.0), 24.0) * 0.25;                      // ореол
	}
	// трещина Раскола: ломаная светлая полоса высоко на севере (-Z)
	float az = atan(d.x, -d.z);
	float crack_y = 0.55 + 0.05 * sin(az * 23.0) + 0.03 * sin(az * 57.0);
	float near_north = smoothstep(0.6, 0.0, abs(az));
	float line = smoothstep(0.012, 0.0, abs(up - crack_y)) * near_north;
	col += rift_color * line * rift_strength;
	COLOR = col;
}

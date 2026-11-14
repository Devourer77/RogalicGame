class_name VfxPlayer
extends Node3D
# Эффекты боя: частицы, вспышки моделей, цифры урона, растворение павших.
# Правил не знает — только показывает то, что ему скажет сцена боя (battle.gd).
# ТЗ и стиль — claude/тз-эффекты.md. Красного здесь нет: он занят зонами угрозы.
#
# Как устроено: каждый «пресет» в PRESETS — описание разового выброса частиц
# (картинка, цвет, сколько, как быстро, куда летят). burst(имя, точка) создаёт
# узел GPUParticles3D, он отыгрывает и сам удаляется.
# Материалы частиц собираются один раз и кэшируются — иначе каждый удар
# заставлял бы видеокарту заново собирать шейдер (короткие подвисания).

# ---------- Ручки ----------
const FULL_EFFECTS: bool = true          # false — «упрощённые»: частиц вдвое меньше
const FLASH_TIME: float = 0.18           # сколько длится вспышка модели при уроне
const DISSOLVE_TIME: float = 0.9         # за сколько секунд павший враг растворяется
const NUMBER_SIZE: int = 96              # размер цифры урона (font_size у Label3D)
const NUMBER_BIG_SIZE: int = 132         # …у сильного удара
const BIG_HIT: int = 8                   # с какого урона удар считается сильным

# Цвета (всё без красного)
const C_HIT := Color(1.0, 0.96, 0.88)            # обычная вспышка и искры
const C_POISON := Color(0.55, 0.95, 0.42)
const C_SHOCK := Color(0.95, 0.95, 0.62)         # молния: бледный холодный жёлтый
const C_WATER := Color(0.55, 0.82, 1.0)
const C_FIRE := Color(1.0, 0.6, 0.18)
const C_STEEL := Color(0.75, 0.83, 0.92)         # блок, сталь Рыцаря
const C_MAGE := Color(0.55, 0.5, 1.0)            # магия Мага — сине-фиолетовая
const C_RIFT := Color(0.37, 0.92, 0.83)          # бирюза Раскола
const C_ASH := Color(0.82, 0.8, 0.74)            # пепел Культа
const C_HEAL := Color(1.0, 0.9, 0.62)            # свечной белый
const C_NUM_DAMAGE := Color(1.0, 0.97, 0.92)
const C_NUM_BLOCK := Color(0.7, 0.8, 0.9)

# Из чего сделан враг — какие искры летят при ударе (по id врага)
const MATERIALS: Dictionary[String, String] = {
	"rock_crawler": "stone", "ogre": "stone",
	"mossy_treant": "wood", "swamp_weaver": "wood", "spiderling": "wood", "weaver_queen": "wood",
	"drowned_walker": "water", "bog_mother": "water", "bloated_toad": "water", "spirit_tide": "water",
	"sporeling": "spore", "reed_lurker": "reed",
	"spirit_storm": "storm", "spirit_wind": "wind", "spirit_bog": "bog",
}

const TEX_DIR: String = "res://assets/textures/vfx/"

# Пресеты разовых выбросов. Поля (все необязательные):
#  tex — картинка, frames — кадров по стороне листа (дым 4×4), color — цвет в начале,
#  color_end — в конце (прозрачность тоже), energy — яркость (>1 светится через glow),
#  amount, life, speed [min, max], spread (градусы), dir — общее направление, gravity,
#  damping — торможение, size [min, max] в метрах, radius — разброс точки появления,
#  add — светящиеся (складываются), stretch — вытягиваются по скорости (искры),
#  spin — вращение (градусов в секунду).
const PRESETS: Dictionary = {
	# Вспышка в точке удара: яркое пятно на долю секунды (главное «попал!»)
	"impact": {"tex": "soft_dot", "color": C_HIT, "energy": 2.2, "amount": 1, "life": 0.12,
		"speed": [0.0, 0.0], "gravity": 0.0, "size": [0.8, 0.8], "add": true},
	# Блик-звезда поверх вспышки
	"impact_star": {"tex": "glint", "color": C_HIT, "energy": 3.0, "amount": 1, "life": 0.16,
		"speed": [0.0, 0.0], "gravity": 0.0, "size": [1.4, 1.4], "add": true, "spin": 90.0},
	# Искры удара: короткие светящиеся черты во все стороны
	"sparks": {"tex": "spark", "color": C_HIT, "energy": 2.5, "amount": 18, "life": 0.35,
		"speed": [2.5, 5.5], "spread": 80.0, "gravity": -9.0, "damping": 4.0,
		"size": [0.11, 0.20], "add": true, "stretch": true},
	# Пыль от удара — мягкий клуб, тает
	"dust": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.62, 0.6, 0.55, 0.55),
		"amount": 6, "life": 0.7, "speed": [0.6, 1.4], "spread": 70.0, "gravity": 0.4,
		"damping": 2.0, "size": [0.5, 0.9], "radius": 0.15, "spin": 40.0},
	# Каменная крошка (скальник, огр)
	"stone": {"tex": "shard", "color": Color(0.55, 0.56, 0.54), "amount": 12, "life": 0.6,
		"speed": [2.0, 4.0], "spread": 70.0, "gravity": -11.0, "size": [0.13, 0.26], "spin": 400.0},
	# Щепки и кора (корягач, пауки)
	"wood": {"tex": "shard", "color": Color(0.5, 0.4, 0.28), "amount": 12, "life": 0.6,
		"speed": [2.0, 4.0], "spread": 75.0, "gravity": -10.0, "size": [0.11, 0.22], "spin": 500.0},
	# Брызги (топляк, жабы, водяные)
	"water": {"tex": "drop", "color": Color(0.6, 0.85, 1.0, 0.9), "energy": 1.4, "amount": 16,
		"life": 0.5, "speed": [2.0, 4.5], "spread": 60.0, "gravity": -12.0, "size": [0.13, 0.24],
		"add": true, "stretch": true},
	# Споры (споровик)
	"spore": {"tex": "soft_dot", "color": Color(0.75, 0.8, 0.45, 0.8), "amount": 16, "life": 1.0,
		"speed": [0.5, 1.6], "spread": 90.0, "gravity": 0.3, "damping": 1.5, "size": [0.11, 0.22],
		"radius": 0.2},
	# Сухой камыш (скрытень)
	"reed": {"tex": "shard", "color": Color(0.7, 0.65, 0.42), "amount": 10, "life": 0.7,
		"speed": [1.5, 3.0], "spread": 80.0, "gravity": -5.0, "damping": 1.5, "size": [0.09, 0.20],
		"spin": 300.0},
	# Разряды (Грозовик)
	"storm": {"tex": "spark", "color": C_SHOCK, "energy": 3.0, "amount": 20, "life": 0.25,
		"speed": [3.0, 6.0], "spread": 90.0, "damping": 6.0, "size": [0.09, 0.18], "add": true,
		"stretch": true},
	# Струйки ветра (Вихорь)
	"wind": {"tex": "soft_dot", "color": Color(0.75, 0.88, 0.78, 0.7), "energy": 1.3, "amount": 14,
		"life": 0.6, "speed": [1.5, 3.0], "spread": 90.0, "damping": 2.5, "size": [0.13, 0.26],
		"add": true},
	# Тина (Хозяин трясины)
	"bog": {"tex": "drop", "color": Color(0.25, 0.38, 0.22), "amount": 14, "life": 0.6,
		"speed": [1.5, 3.5], "spread": 70.0, "gravity": -10.0, "size": [0.15, 0.26], "stretch": true},
	# Удар в блок: стальные искры, плотный веер
	"block": {"tex": "spark", "color": C_STEEL, "energy": 3.0, "amount": 22, "life": 0.3,
		"speed": [3.0, 6.0], "spread": 55.0, "gravity": -6.0, "damping": 5.0,
		"size": [0.09, 0.15], "add": true, "stretch": true},
	# Блок сломан: осколки сияния щита
	"block_break": {"tex": "shard", "color": C_STEEL, "energy": 2.0, "amount": 14, "life": 0.6,
		"speed": [2.0, 4.0], "spread": 90.0, "gravity": -8.0, "size": [0.18, 0.31], "add": true,
		"spin": 600.0},
	# Яд: зелёные пузырьки вверх
	"poison": {"tex": "soft_dot", "color": C_POISON, "energy": 1.6, "amount": 12, "life": 0.7,
		"speed": [0.6, 1.4], "dir": Vector3.UP, "spread": 35.0, "gravity": 0.8, "damping": 1.0,
		"size": [0.11, 0.22], "radius": 0.25, "add": true},
	# Молния по цели
	"shock": {"tex": "spark", "color": C_SHOCK, "energy": 3.5, "amount": 16, "life": 0.22,
		"speed": [3.0, 7.0], "spread": 90.0, "damping": 8.0, "size": [0.09, 0.18],
		"add": true, "stretch": true},
	# Огонь по цели: угольки вверх
	"embers": {"tex": "soft_dot", "color": C_FIRE, "energy": 2.5, "amount": 14, "life": 0.6,
		"speed": [1.0, 2.5], "dir": Vector3.UP, "spread": 45.0, "gravity": 1.5, "damping": 1.5,
		"size": [0.09, 0.18], "radius": 0.2, "add": true},
	# Лечение: тёплые звёздочки снизу вверх
	"heal": {"tex": "glint", "color": C_HEAL, "energy": 2.2, "amount": 14, "life": 0.9,
		"speed": [0.6, 1.4], "dir": Vector3.UP, "spread": 20.0, "gravity": 0.5, "damping": 0.8,
		"size": [0.22, 0.40], "radius": 0.35, "add": true},
	# Смерть твари Раскола: бирюзовые огоньки поднимаются и гаснут
	"rift_motes": {"tex": "soft_dot", "color": C_RIFT, "energy": 2.8, "amount": 26, "life": 1.2,
		"speed": [0.4, 1.4], "dir": Vector3.UP, "spread": 50.0, "gravity": 0.9, "damping": 0.6,
		"size": [0.11, 0.24], "radius": 0.4, "add": true},
	# Смерть культиста: хлопья пепла медленно опадают
	"ash": {"tex": "ash", "color": C_ASH, "amount": 22, "life": 1.6, "speed": [0.3, 1.0],
		"dir": Vector3.UP, "spread": 70.0, "gravity": -0.6, "damping": 0.8, "size": [0.13, 0.26],
		"radius": 0.4, "spin": 120.0},
	# Утонул: всплеск
	"splash": {"tex": "drop", "color": Color(0.55, 0.75, 0.7, 0.9), "energy": 1.2, "amount": 26,
		"life": 0.7, "speed": [2.5, 5.0], "dir": Vector3.UP, "spread": 30.0, "gravity": -12.0,
		"size": [0.15, 0.29], "radius": 0.25, "stretch": true},
}

var _process_cache: Dictionary = {}   # имя пресета → ParticleProcessMaterial
var _draw_cache: Dictionary = {}      # имя пресета → QuadMesh с материалом
var _flash_shader: Shader = preload("res://assets/shaders/vfx/hit_flash.gdshader")
var _dissolve_shader: Shader = preload("res://assets/shaders/vfx/dissolve.gdshader")
var _ring_mat: StandardMaterial3D


# Заранее собираем все материалы и один раз «выпускаем» каждый пресет под полем,
# чтобы видеокарта скомпилировала шейдеры до первого удара, а не во время него.
func warm_up() -> void:
	for preset_name: String in PRESETS:
		burst(preset_name, Vector3(0.0, -50.0, 0.0), 1.0, 1)
	ring(Vector3(0.0, -50.0, 0.0), C_HIT, 0.5, 0.05)


# ---------- Частицы ----------

# Разовый выброс частиц пресета в точке. scale — во сколько раз крупнее и сильнее,
# amount_override — сколько частиц (0 — как в пресете), color_override — другой цвет.
func burst(preset_name: String, at: Vector3, scale: float = 1.0, amount_override: int = 0,
		color_override: Color = Color(0, 0, 0, 0)) -> void:
	var p: Dictionary = PRESETS[preset_name]
	var parts := GPUParticles3D.new()
	parts.one_shot = true
	parts.explosiveness = 0.95
	var amount: int = amount_override if amount_override > 0 else int(round(p.get("amount", 12) * scale))
	if not FULL_EFFECTS:
		amount = maxi(1, amount / 2)
	parts.amount = maxi(1, amount)
	parts.lifetime = p.get("life", 0.5)
	parts.fixed_fps = 0   # считаем каждый кадр — плавнее на быстрых частицах
	parts.process_material = _process_for(preset_name, color_override)
	parts.draw_pass_1 = _draw_for(preset_name)
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	parts.position = at
	parts.amount_ratio = 1.0
	parts.speed_scale = 1.0
	if scale != 1.0:
		parts.scale = Vector3.ONE * sqrt(scale)
	add_child(parts)
	parts.emitting = true
	parts.finished.connect(parts.queue_free)


# tint — другой цвет вместо цвета пресета (прозрачный Color — без замены)
func _process_for(preset_name: String, tint: Color = Color(0, 0, 0, 0)) -> ParticleProcessMaterial:
	var key: String = preset_name if tint.a <= 0.0 else "%s_%s" % [preset_name, tint.to_html()]
	if _process_cache.has(key):
		return _process_cache[key]
	var p: Dictionary = PRESETS[preset_name]
	var m := ParticleProcessMaterial.new()
	m.direction = p.get("dir", Vector3.UP)
	m.spread = p.get("spread", 60.0)
	var speed: Array = p.get("speed", [1.0, 2.0])
	m.initial_velocity_min = speed[0]
	m.initial_velocity_max = speed[1]
	m.gravity = Vector3(0.0, p.get("gravity", -4.0), 0.0)
	var damping: float = p.get("damping", 0.0)
	m.damping_min = damping * 0.8
	m.damping_max = damping
	var size: Array = p.get("size", [0.05, 0.1])
	m.scale_min = size[0]
	m.scale_max = size[1]
	var radius: float = p.get("radius", 0.0)
	if radius > 0.0:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = radius
	if p.get("stretch", false):
		m.particle_flag_align_y = true
	var spin: float = p.get("spin", 0.0)
	if spin > 0.0:
		m.angle_min = -180.0
		m.angle_max = 180.0
		m.angular_velocity_min = -spin
		m.angular_velocity_max = spin
	if p.get("frames", 1) > 1:
		m.anim_speed_min = 1.0
		m.anim_speed_max = 1.0
	# Размер: быстро вырастает и плавно уменьшается к концу жизни
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.25 if p.get("frames", 1) == 1 else 1.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	m.scale_curve = curve_tex
	# Цвет и прозрачность: от яркого к угасшему
	var c: Color = p.get("color", C_HIT) if tint.a <= 0.0 else tint
	var energy: float = p.get("energy", 1.0)
	var start := Color(c.r * energy, c.g * energy, c.b * energy, c.a)
	var finish: Color = p.get("color_end", Color(start.r, start.g, start.b, 0.0))
	var grad := Gradient.new()
	grad.set_color(0, start)
	grad.set_color(1, finish)
	grad.add_point(0.6, Color(start.r, start.g, start.b, start.a * 0.8))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	grad_tex.use_hdr = true   # цвета ярче 1.0 — так их подхватывает свечение (glow)
	m.color_ramp = grad_tex
	_process_cache[key] = m
	return m


func _draw_for(preset_name: String) -> QuadMesh:
	if _draw_cache.has(preset_name):
		return _draw_cache[preset_name]
	var p: Dictionary = PRESETS[preset_name]
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	if p.get("stretch", false):
		quad.size = Vector2(0.5, 2.5)   # искры и капли вытянуты вдоль полёта
	quad.material = _make_draw_material(p)
	_draw_cache[preset_name] = quad
	return quad


func _make_draw_material(p: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load(TEX_DIR + String(p.get("tex", "soft_dot")) + ".png")
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if p.get("add", false):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Искры смотрят на камеру, но вытянуты по скорости (Fixed Y + align_y в ParticleProcessMaterial)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if p.get("stretch", false) else BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	var frames: int = p.get("frames", 1)
	if frames > 1:
		mat.particles_anim_h_frames = frames
		mat.particles_anim_v_frames = frames
		mat.particles_anim_loop = false
	return mat


# Плоское кольцо на земле: расходится и тает (ударная волна, круги на воде)
func ring(at: Vector3, color: Color, size: float = 1.6, time: float = 0.35, energy: float = 2.0) -> void:
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_mat.albedo_texture = load(TEX_DIR + "ring.png")
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat: StandardMaterial3D = _ring_mat.duplicate()
	mat.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.scale = Vector3.ONE * size * 0.25
	add_child(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)


# Короткая вспышка света: освещает модели вокруг (взрыв, молния, сильный удар)
func light_flash(at: Vector3, color: Color, energy: float = 3.0, radius: float = 3.5, time: float = 0.2) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	light.position = at
	add_child(light)
	var tween: Tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)


# ---------- Модели ----------

# Все сетки модели фигурки (без плашки и подсветок)
func _meshes(view: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in view.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


# Вспышка модели при уроне: поверх всех материалов кладём светящийся слой и гасим его
func flash(view: Node3D, color: Color = C_HIT, strength: float = 1.0) -> void:
	var mat: ShaderMaterial
	if view.has_meta("flash_mat"):
		mat = view.get_meta("flash_mat")
	else:
		mat = ShaderMaterial.new()
		mat.shader = _flash_shader
		view.set_meta("flash_mat", mat)
		for m in _meshes(view):
			m.material_overlay = mat
	mat.set_shader_parameter("flash_color", color)
	var tween: Tween = view.create_tween()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v),
			strength, 0.0, FLASH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# Растворение павшего: каждый материал модели меняем на «растворяющийся» с теми же цветами
# и за DISSOLVE_TIME прожигаем дыры. В конце фигурка прячется.
func dissolve(view: Node3D, edge: Color, height: float) -> void:
	var mats: Array[ShaderMaterial] = []
	for m in _meshes(view):
		m.material_overlay = null
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var old: Material = m.get_active_material(i)
			var sm := ShaderMaterial.new()
			sm.shader = _dissolve_shader
			if old is BaseMaterial3D:
				var b: BaseMaterial3D = old
				sm.set_shader_parameter("albedo", b.albedo_color)
				if b.albedo_texture != null:
					sm.set_shader_parameter("albedo_texture", b.albedo_texture)
				sm.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
				if b.emission_enabled:
					sm.set_shader_parameter("emission_color", b.emission)
					sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
				sm.set_shader_parameter("roughness", b.roughness)
			sm.set_shader_parameter("edge_color", edge)
			sm.set_shader_parameter("base_y", view.global_position.y)
			sm.set_shader_parameter("height", height)
			m.set_surface_override_material(i, sm)
			mats.append(sm)
	var tween: Tween = view.create_tween()
	tween.tween_method(func(v: float) -> void:
		for sm in mats:
			sm.set_shader_parameter("progress", v), 0.0, 1.0, DISSOLVE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: view.visible = false)


# ---------- Цифры ----------

# Цифра над точкой: выскакивает с «подпрыгиванием», всплывает и тает.
# big — крупнее (сильный удар).
func number(at: Vector3, text: String, color: Color, big: bool = false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.font_bold()
	label.font_size = NUMBER_BIG_SIZE if big else NUMBER_SIZE
	label.pixel_size = 0.006
	label.outline_size = 18
	label.outline_modulate = Color(0.05, 0.06, 0.07, 0.9)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.position = at + Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.05), 0.0)
	label.scale = Vector3.ONE * 0.3
	add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.15, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector3.ONE, 0.08)
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.75).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.3)
	tween.tween_callback(label.queue_free)


# ---------- Готовые сочетания для сцены боя ----------

# Направление «вправо» на экране (в мире) — чтобы ставить цифры сбоку от фигурки
func _camera_right() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.RIGHT
	var r: Vector3 = cam.global_basis.x
	r.y = 0.0
	return r.normalized() if r.length() > 0.01 else Vector3.RIGHT


# Направление от точки к камере
func _to_camera(at: Vector3) -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	return (cam.global_position - at).normalized()


# Из чего сделан юнит: id врага → вид искр. Герои: Рыцарь — сталь, Маг — обычные искры.
static func material_of(enemy_id: String, hero_id: String = "") -> String:
	if hero_id == "knight":
		return "block"
	return MATERIALS.get(enemy_id, "sparks")


# Удар по юниту. view — фигурка, height — её рост, info — что случилось:
#  dealt (урон по HP), absorbed (сколько съел блок), broke (блок кончился),
#  source ("poison", "fire", "lava", "gas", "steam", "bump", "" — обычный удар),
#  element (CardData.Element или -1), material (из material_of), killed.
func hit(view: Node3D, height: float, info: Dictionary) -> void:
	var dealt: int = info.get("dealt", 0)
	var absorbed: int = info.get("absorbed", 0)
	var source: String = info.get("source", "")
	var element: int = info.get("element", -1)
	var big: bool = dealt >= BIG_HIT or info.get("killed", false)
	var body: Vector3 = view.global_position + Vector3(0.0, height * 0.5, 0.0)
	# Цифры — сбоку от фигурки на уровне груди: над головой уже плашка с HP
	var right: Vector3 = _camera_right()
	var num_at: Vector3 = view.global_position + Vector3(0.0, height * 0.75, 0.0)
	var front: Vector3 = body + _to_camera(body) * 0.35   # вспышка — чуть ближе к камере, не внутри модели
	var flash_color: Color = C_HIT
	var power: float = 1.4 if big else 1.0

	# Чем ударили — главный эффект
	if source == "poison":
		flash_color = C_POISON
		burst("poison", body)
	elif source == "fire" or source == "lava" or element == CardData.Element.FIRE:
		flash_color = C_FIRE
		burst("embers", body, power)
	elif element == CardData.Element.LIGHTNING:
		flash_color = C_SHOCK
		burst("shock", body, power)
		light_flash(body, C_SHOCK, 2.5, 3.0, 0.15)
	elif element == CardData.Element.WATER:
		flash_color = C_WATER
		burst("water", body, power)
	elif source == "gas":
		flash_color = C_POISON
		burst("poison", body, 1.2)
	elif source == "steam":
		burst("dust", body, 1.2, 0, Color(0.95, 0.97, 1.0, 0.7))

	if absorbed > 0:
		# Удар в блок: стальной веер искр и кольцо
		burst("block", body, power)
		ring(view.global_position + Vector3(0.0, 0.06, 0.0), C_STEEL, 1.3, 0.3, 1.6)
		if info.get("broke", false) and dealt > 0:
			burst("block_break", body)
		number(num_at - right * 0.5, "−%d" % absorbed, C_NUM_BLOCK, false)

	if dealt > 0:
		# Искры по материалу цели (у яда — только пузырьки, без искр)
		if source != "poison":
			var mat_name: String = info.get("material", "sparks")
			if mat_name == "block":
				mat_name = "sparks"   # Рыцарь без блока — обычные искры
			burst(mat_name, body, power)
			if mat_name == "sparks" and big:
				burst("dust", view.global_position + Vector3(0, 0.2, 0), 1.0)
		flash(view, flash_color, 1.0)
		if source != "poison":
			burst("impact", front, 1.3 if big else 1.0, 1, flash_color)
			if big:
				burst("impact_star", front, 1.0, 1, flash_color)
		var num_color: Color = C_POISON if source == "poison" else C_NUM_DAMAGE
		number(num_at + right * 0.5, "−%d" % dealt, num_color, big)
		if big:
			light_flash(body, flash_color, 1.6, 2.5, 0.15)
	elif absorbed > 0:
		flash(view, C_STEEL, 0.5)


# Лечение: тёплые искры и «+N»
func heal(view: Node3D, height: float, amount: int) -> void:
	burst("heal", view.global_position + Vector3(0.0, 0.3, 0.0))
	flash(view, C_HEAL, 0.5)
	number(view.global_position + Vector3(0.0, height * 0.75, 0.0) + _camera_right() * 0.5, "+%d" % amount, C_HEAL)


# Смерть врага: растворение и огоньки. kind: "rift" (твари), "cult", "spirit" (дух покорён)
func death(view: Node3D, height: float, kind: String, spirit_color: Color = C_RIFT) -> void:
	var at: Vector3 = view.global_position + Vector3(0.0, height * 0.45, 0.0)
	if kind == "cult":
		dissolve(view, C_ASH * 1.3, height)
		burst("ash", at)
	elif kind == "spirit":
		burst("rift_motes", at, 1.2, 0, spirit_color)
		light_flash(at, spirit_color, 3.0, 4.0, 0.5)
	else:
		dissolve(view, C_RIFT, height)
		burst("rift_motes", at)
		light_flash(at, C_RIFT, 1.5, 3.0, 0.6)


# Утонул: всплеск и круги на воде
func sink(view: Node3D) -> void:
	var at: Vector3 = view.global_position
	burst("splash", at + Vector3(0.0, 0.1, 0.0))
	ring(at + Vector3(0.0, 0.05, 0.0), Color(0.6, 0.8, 0.75), 1.4, 0.6, 1.0)
	ring(at + Vector3(0.0, 0.05, 0.0), Color(0.6, 0.8, 0.75), 2.2, 1.0, 0.7)

class_name UiFx
extends RefCounted
# Эффекты интерфейса (этап 7 ТЗ claude/тз-эффекты.md): 2D-частицы и блеск поверх экранов.
# Всё здесь только украшает: ни на что не нажимается (mouse_filter = IGNORE) и само удаляется.
#   card_burst — сыгранная карта вспыхивает и рассыпается искрами цвета своего набора
#   shine      — по выбранной кнопке/карте пробегает блик, вокруг блёстки
#   card_toast — карта ненадолго показывается по центру с блеском (куплена, улучшена)

const TEX_DOT: String = "res://assets/textures/vfx/soft_dot.png"
const TEX_GLINT: String = "res://assets/textures/vfx/glint.png"


# Сыгранная карта: на её месте вспышка, и карта рассыпается искрами вверх.
# layer — куда добавить эффект (корень интерфейса), rect — где была карта (в координатах layer).
static func card_burst(layer: Control, rect: Rect2, color: Color) -> void:
	if layer == null or not layer.is_inside_tree():
		return
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = rect.position
	holder.size = rect.size
	holder.z_index = 50
	layer.add_child(holder)
	# Вспышка: светлый прямоугольник карты быстро гаснет и чуть растёт
	var flash := Panel.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.97, 0.88).lerp(color, 0.35)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(color, 0.8)
	box.shadow_size = 18
	flash.add_theme_stylebox_override("panel", box)
	flash.size = rect.size
	flash.pivot_offset = rect.size * 0.5
	flash.material = _add_material()
	holder.add_child(flash)
	var tween: Tween = flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3).from(0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector2.ONE * 1.12, 0.3).set_ease(Tween.EASE_OUT)
	# Искры по всей площади карты, летят вверх и гаснут
	var sparks: CPUParticles2D = _particles(TEX_DOT, color, 70, 0.75)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = rect.size * 0.5
	sparks.position = rect.size * 0.5
	sparks.direction = Vector2.UP
	sparks.spread = 50.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 240.0
	sparks.gravity = Vector2(0.0, -120.0)
	sparks.damping_min = 40.0
	sparks.damping_max = 90.0
	sparks.scale_amount_min = 0.12
	sparks.scale_amount_max = 0.35
	holder.add_child(sparks)
	sparks.emitting = true
	layer.get_tree().create_timer(1.0).timeout.connect(holder.queue_free)


# Блеск по выбранному: блик-полоса пробегает наискосок, вокруг блёстки
static func shine(target: Control, color: Color = UiKit.BRASS) -> void:
	if target == null or not target.is_inside_tree():
		return
	var size: Vector2 = target.size
	# Блик — светлая полоса внутри рамки кнопки (за края не вылезает)
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.size = size
	clip.z_index = 5
	target.add_child(clip)
	var band := ColorRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.color = Color(1.0, 0.95, 0.8, 0.3)
	band.material = _add_material()
	band.size = Vector2(size.x * 0.12, size.y * 2.0)
	band.pivot_offset = band.size * 0.5
	band.rotation = deg_to_rad(20.0)
	band.position = Vector2(-band.size.x * 2.0, -size.y * 0.5)
	clip.add_child(band)
	var tween: Tween = band.create_tween()
	tween.tween_property(band, "position:x", size.x + band.size.x, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(clip.queue_free)
	# Блёстки вдоль рамки
	var glints: CPUParticles2D = _particles(TEX_GLINT, color.lightened(0.3), 18, 0.8)
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glints.emission_rect_extents = size * 0.5
	glints.position = size * 0.5
	glints.spread = 180.0
	glints.initial_velocity_min = 10.0
	glints.initial_velocity_max = 40.0
	glints.gravity = Vector2.ZERO
	glints.scale_amount_min = 0.25
	glints.scale_amount_max = 0.5
	glints.angular_velocity_min = -120.0
	glints.angular_velocity_max = 120.0
	glints.z_index = 6
	target.add_child(glints)
	glints.emitting = true
	target.get_tree().create_timer(1.2).timeout.connect(glints.queue_free)
	# Масштаб и точку поворота кнопки не трогаем: карты на экранах бывают уменьшены,
	# и любая правка сдвинула бы их с места


# Карта по центру экрана на миг — с блеском и тёплым свечением, потом тает.
# Для лавки: куплена или улучшена карта, а сам экран при этом перестраивается.
static func card_toast(parent: Control, card: CardData, owner_color: Color, caption: String = "") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.z_index = 60
	parent.add_child(holder)
	# Затемнение под картой — чтобы она читалась поверх кнопок экрана
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.02, 0.03, 0.03, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)
	var view: Button = CardView.make_button(card, owner_color)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.focus_mode = Control.FOCUS_NONE
	var screen: Vector2 = parent.get_viewport_rect().size
	view.position = screen * 0.5 - CardView.CARD_SIZE * 0.5
	view.pivot_offset = CardView.CARD_SIZE * 0.5
	view.scale = Vector2.ONE * 0.6
	holder.add_child(view)
	if caption != "":
		var label: Label = UiKit.make_label(caption, 22, UiKit.BRASS.lightened(0.25))
		# Подпись под картой (сверху обычно заголовок экрана)
		label.position = Vector2(screen.x * 0.5 - 200.0, screen.y * 0.5 + CardView.CARD_SIZE.y * 0.65 + 8.0)
		label.size = Vector2(400.0, 36.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 0.9))
		label.add_theme_constant_override("outline_size", 6)
		holder.add_child(label)
	var tween: Tween = holder.create_tween()
	tween.tween_property(view, "scale", Vector2.ONE * 1.25, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void: shine(view, UiKit.BRASS))
	tween.tween_interval(0.75)
	tween.tween_property(holder, "modulate:a", 0.0, 0.3)
	tween.tween_callback(holder.queue_free)


# Частицы с мягкой текстурой: цвет от яркого к прозрачному
static func _particles(texture_path: String, color: Color, amount: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load(texture_path)
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.85
	p.material = _add_material()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 1.0, 1.0).lerp(color, 0.4), color, Color(color, 0.0)])
	p.color_ramp = ramp
	return p


# Светящееся наложение: цвет складывается с фоном
static func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

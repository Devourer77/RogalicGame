# Стилизация low-poly модели перед экспортом: запекает «нарисованный» объём в текстуру.
#
# Что делает с однотонной моделью:
#   - затемняет складки и стыки холодной тенью (Ambient Occlusion, только сама модель);
#   - светлит выпуклые рёбра (через Bevel — работает и на моделях из 50 треугольников);
#   - делает низ темнее, верх светлее (градиент «модель стоит на земле»);
#   - чуть светлит грани, смотрящие вверх, и темнит смотрящие вниз.
# Всё это запекается в одну картинку цвета (albedo). Шероховатость, металл и свечение
# каждого материала переносятся в свои картинки как есть, без шума.
# Прозрачные материалы (вода, стекло) не трогаются и остаются отдельными.
#
# Вызов из скрипта сборки (char_kit.export, build_topi.build_all):
#   import stylize
#   stylize.stylize(obj, tex_dir, size=512)
# Потом модель экспортируется в .glb как обычно — картинки попадают внутрь .glb.
#
# Отдельно в Blender: выдели модель → Scripting → Open stylize.py → Run Script.
#
# Кроме картинок, скрипт кладёт во второй UV-слой «RestUV» координаты точки на теле
# в позе покоя (обхват и высота от 0 до 1). По ним шейдер состояний в Godot рисует
# яд и тину так, что узор не «плывёт», когда модель двигается.
import bpy, bmesh, math, os

# ---------------- Ручки ----------------
STYLIZE = True          # False — модели собираются по-старому, однотонными
SIZE_UNIT = 512         # текстура рядового врага и объекта
SIZE_BIG = 1024         # героя, босса и крупного декора
BIG_CHARACTERS = {"hero", "knight", "ogre", "bog_mother", "drowned_captain", "spirit_fire"}   # герои и боссы
SAMPLES = 96            # сэмплы Cycles; запекание не очищается денойзером, меньше 64 — зерно
AO_DISTANCE = 0.40      # радиус тени в складках, м
AO_STRENGTH = 0.90      # насколько темнеют складки (0 — нет)
AO_SHADOW = (0.30, 0.31, 0.40)   # цвет глубокой тени (холодный, в тон туману топей)
EDGE_RADIUS = 0.015     # ширина светлой кромки на рёбрах, м
EDGE_STRENGTH = 0.75    # насколько светлеет кромка (в цвет самой детали, не в белый)
GRADIENT_LOW = 0.55     # яркость у земли (1.0 — без градиента)
GRADIENT_SPAN = 1.6     # высота, на которой градиент доходит до 1, м (у высоких моделей низ темнее только внизу)
TOP_LIGHT = 0.10        # верхние грани светлее, нижние темнее на столько
MARGIN = 16             # запас краски за краем UV-островов, пикселей (нужен для мипмапов)


def _srgb_to_lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def _read_material(m):
    """Достаёт из материала то, что нужно для запекания."""
    info = {"color": (0.5, 0.5, 0.5, 1.0), "color_link": None, "rough": 0.8, "metal": 0.0,
            "emit": (0.0, 0.0, 0.0), "emit_strength": 0.0, "transparent": False}
    if m is None:
        return info
    if not m.use_nodes:
        info["color"] = tuple(m.diffuse_color)
        return info
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return info
    bc = bsdf.inputs["Base Color"]
    info["color"] = tuple(bc.default_value)
    if bc.is_linked and bc.links[0].from_node.type == "TEX_IMAGE":
        info["color_link"] = bc.links[0].from_node.image
    info["rough"] = bsdf.inputs["Roughness"].default_value
    info["metal"] = bsdf.inputs["Metallic"].default_value
    info["emit"] = tuple(bsdf.inputs["Emission Color"].default_value)[:3]
    info["emit_strength"] = bsdf.inputs["Emission Strength"].default_value
    alpha = bsdf.inputs["Alpha"].default_value
    info["transparent"] = alpha < 0.999 or getattr(m, "surface_render_method", "DITHERED") == "BLENDED"
    return info


def _add_bake_uv(obj):
    """Свой UV-слой под запекание: острова без наложений. Старые UV не трогаем."""
    me = obj.data
    uv = me.uv_layers.get("BakeUV") or me.uv_layers.new(name="BakeUV")
    me.uv_layers.active = uv
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.reveal()
    bpy.ops.mesh.select_all(action="SELECT")
    # Острова по углу 50°: у low-poly почти каждая сторона — свой остров, тени не текут через рёбра
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=0.012, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.012, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    # BakeUV должен быть первым (TEXCOORD_0 в .glb): удаляем старые слои, если были
    for other in [l for l in me.uv_layers if l.name not in ("BakeUV",)]:
        me.uv_layers.remove(other)
    uv = me.uv_layers["BakeUV"]
    uv.active_render = True
    return uv


def _add_rest_uv(obj, min_z, max_z):
    """Второй UV-слой: обхват (0..1 по кругу) и высота (0..1) точки в позе покоя."""
    me = obj.data
    rest = me.uv_layers.get("RestUV") or me.uv_layers.new(name="RestUV")
    h = max(max_z - min_z, 1e-4)
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = math.atan2(co.x, -co.y) / (2 * math.pi) + 0.5
            rest.data[li].uv = (u, (co.z - min_z) / h)
    me.uv_layers.active = me.uv_layers["BakeUV"]


def _bake_material(info, mode, edge_radius, min_z, max_z, emit_max, image):
    """Временный материал для одного прохода: всё нужное выводится через Emission."""
    m = bpy.data.materials.new("_bake_tmp")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N, L = nt.nodes, nt.links
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    L.new(em.outputs["Emission"], out.inputs["Surface"])
    tex = N.new("ShaderNodeTexImage")
    tex.image = image
    nt.nodes.active = tex   # сюда Cycles пишет результат

    def value(v):
        n = N.new("ShaderNodeValue")
        n.outputs[0].default_value = v
        return n.outputs[0]

    if mode == "rough":
        L.new(value(info["rough"]), em.inputs["Color"])
        return m
    if mode == "metal":
        L.new(value(info["metal"]), em.inputs["Color"])
        return m
    if mode == "emit":
        k = info["emit_strength"] / emit_max if emit_max > 0 else 0.0
        em.inputs["Color"].default_value = (*[c * k for c in info["emit"]], 1.0)
        return m
    if info["transparent"]:
        em.inputs["Color"].default_value = info["color"]
        return m

    # ---- проход цвета ----
    if info["color_link"] is not None:
        src = N.new("ShaderNodeTexImage")
        src.image = info["color_link"]
        base = src.outputs["Color"]
    else:
        rgb = N.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = info["color"]
        base = rgb.outputs[0]

    def mix(a, b, blend, fac):
        n = N.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = blend
        n.clamp_result = True
        n.inputs[0].default_value = fac
        L.new(a, n.inputs[6])
        L.new(b, n.inputs[7])
        return n.outputs[2]

    # 1. Тень в складках — только от самой модели (only_local), чужие объекты сцены не мешают
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.samples = 4   # шум усредняется сэмплами прохода (SAMPLES), здесь много не нужно
    ao.only_local = True
    ao.inputs["Distance"].default_value = AO_DISTANCE
    ao_ramp = N.new("ShaderNodeValToRGB")
    ao_ramp.color_ramp.interpolation = "EASE"
    e0, e1 = ao_ramp.color_ramp.elements
    e0.position, e0.color = 0.15, (*_srgb_to_lin(AO_SHADOW), 1.0)
    e1.position, e1.color = 0.90, (1.0, 1.0, 1.0, 1.0)
    L.new(ao.outputs["AO"], ao_ramp.inputs["Fac"])
    col = mix(base, ao_ramp.outputs["Color"], "MULTIPLY", AO_STRENGTH)

    # 2. Градиент по высоте: у земли темнее
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])
    grad = N.new("ShaderNodeMapRange")
    grad.clamp = True
    grad.inputs["From Min"].default_value = min_z
    grad.inputs["From Max"].default_value = min_z + min(max_z - min_z, GRADIENT_SPAN)
    grad.inputs["To Min"].default_value = GRADIENT_LOW
    grad.inputs["To Max"].default_value = 1.0
    L.new(sep.outputs["Z"], grad.inputs["Value"])

    # 3. Свет сверху: грани, смотрящие вверх, чуть светлее
    geo = N.new("ShaderNodeNewGeometry")
    sep_n = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["True Normal"], sep_n.inputs["Vector"])   # мировая нормаль; модель стоит в начале координат
    top = N.new("ShaderNodeMapRange")
    top.inputs["From Min"].default_value = -1.0
    top.inputs["From Max"].default_value = 1.0
    top.inputs["To Min"].default_value = 1.0 - TOP_LIGHT
    top.inputs["To Max"].default_value = 1.0 + TOP_LIGHT
    L.new(sep_n.outputs["Z"], top.inputs["Value"])
    shade = N.new("ShaderNodeMath")
    shade.operation = "MULTIPLY"
    L.new(grad.outputs["Result"], shade.inputs[0])
    L.new(top.outputs["Result"], shade.inputs[1])
    shade_rgb = N.new("ShaderNodeCombineColor")
    for i in range(3):
        L.new(shade.outputs[0], shade_rgb.inputs[i])
    col = mix(col, shade_rgb.outputs[0], "MULTIPLY", 1.0)

    # 4. Светлая кромка на выпуклых рёбрах: Bevel скругляет нормаль у ребра,
    #    разница с настоящей нормалью = «насколько близко ребро». Во впадинах кромку гасит AO.
    bev = N.new("ShaderNodeBevel")
    bev.samples = 4
    bev.inputs["Radius"].default_value = edge_radius
    dot = N.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    L.new(bev.outputs["Normal"], dot.inputs[0])
    L.new(geo.outputs["True Normal"], dot.inputs[1])
    edge = N.new("ShaderNodeMapRange")
    edge.clamp = True
    edge.inputs["From Min"].default_value = 0.995
    edge.inputs["From Max"].default_value = 0.90
    L.new(dot.outputs["Value"], edge.inputs["Value"])
    convex = N.new("ShaderNodeMapRange")   # кромка только там, где модель не затенена складкой
    convex.clamp = True
    convex.inputs["From Min"].default_value = 0.70
    convex.inputs["From Max"].default_value = 0.95
    L.new(ao.outputs["AO"], convex.inputs["Value"])
    edge_k = N.new("ShaderNodeMath")
    edge_k.operation = "MULTIPLY"
    L.new(edge.outputs["Result"], edge_k.inputs[0])
    L.new(convex.outputs["Result"], edge_k.inputs[1])
    # Кромка — та же краска, только светлее: цвет × (1 + сила) и чуть приподнятые тёмные тона
    lit = N.new("ShaderNodeMix")
    lit.data_type = "RGBA"
    lit.blend_type = "MULTIPLY"
    lit.inputs[0].default_value = 1.0
    L.new(col, lit.inputs[6])
    lit.inputs[7].default_value = (1.0 + EDGE_STRENGTH,) * 3 + (1.0,)
    lift = N.new("ShaderNodeMix")
    lift.data_type = "RGBA"
    lift.blend_type = "ADD"
    lift.inputs[0].default_value = 1.0
    L.new(lit.outputs[2], lift.inputs[6])
    lift.inputs[7].default_value = (0.012, 0.012, 0.012, 1.0)
    scr = N.new("ShaderNodeMix")
    scr.data_type = "RGBA"
    scr.blend_type = "MIX"
    scr.clamp_result = True
    L.new(edge_k.outputs[0], scr.inputs[0])
    L.new(col, scr.inputs[6])
    L.new(lift.outputs[2], scr.inputs[7])
    L.new(scr.outputs[2], em.inputs["Color"])
    return m


def _bake(obj, infos, mode, image, edge_radius, min_z, max_z, emit_max):
    # Шероховатость, металл и свечение — ровные значения по граням, им хватает 4 сэмплов.
    # Дорогой только проход цвета (тени и кромки).
    bpy.context.scene.cycles.samples = SAMPLES if mode == "color" else 4
    tmp = [_bake_material(i, mode, edge_radius, min_z, max_z, emit_max, image) for i in infos]
    for slot, m in zip(obj.material_slots, tmp):
        slot.material = m
    bpy.ops.object.bake(type="EMIT", margin=MARGIN, margin_type="EXTEND", use_clear=True,
                        target="IMAGE_TEXTURES")
    for m in tmp:
        bpy.data.materials.remove(m)


def _new_image(name, size, color_data):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "sRGB" if color_data else "Non-Color"
    return img


def stylize(obj, tex_dir=None, size=SIZE_UNIT, edge_radius=EDGE_RADIUS):
    """Запекает стилизацию в текстуры и ставит модели один материал с ними.
    Возвращает obj. Модель должна быть в позе покоя (у персонажей — до анимаций)."""
    if not STYLIZE or obj.type != "MESH":
        return obj
    size = int(os.environ.get("STYLIZE_SIZE", size))   # для быстрых проб: STYLIZE_SIZE=256
    scene = bpy.context.scene
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    me = obj.data
    if not obj.material_slots:
        me.materials.append(bpy.data.materials.new(obj.name + "_Mat"))
    originals = [s.material for s in obj.material_slots]
    infos = [_read_material(m) for m in originals]
    zs = [v.co.z for v in me.vertices]
    min_z, max_z = min(zs), max(zs)
    emit_max = max([i["emit_strength"] for i in infos] + [0.0])

    _add_bake_uv(obj)
    _add_rest_uv(obj, min_z, max_z)

    old_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = False   # на запекание денойзер всё равно не действует

    name = obj.name
    img_col = _new_image(name + "_albedo", size, True)
    _bake(obj, infos, "color", img_col, edge_radius, min_z, max_z, emit_max)
    img_r = _new_image(name + "_r", size, False)
    _bake(obj, infos, "rough", img_r, edge_radius, min_z, max_z, emit_max)
    img_m = _new_image(name + "_m", size, False)
    _bake(obj, infos, "metal", img_m, edge_radius, min_z, max_z, emit_max)
    img_e = None
    if emit_max > 0:
        img_e = _new_image(name + "_emission", size, True)
        _bake(obj, infos, "emit", img_e, edge_radius, min_z, max_z, emit_max)

    # Шероховатость и металл — в одну картинку, как любит glTF: G — шероховатость, B — металл
    img_orm = _new_image(name + "_orm", size, False)
    r = list(img_r.pixels)
    mt = list(img_m.pixels)
    px = [1.0] * (size * size * 4)
    px[1::4] = r[0::4]
    px[2::4] = mt[0::4]
    img_orm.pixels = px
    bpy.data.images.remove(img_r)
    bpy.data.images.remove(img_m)

    images = [img_col, img_orm] + ([img_e] if img_e else [])
    for img in images:
        if tex_dir:
            os.makedirs(tex_dir, exist_ok=True)
            img.filepath_raw = os.path.join(tex_dir, img.name + ".png")
            img.file_format = "PNG"
            img.save()
        img.pack()

    # Итоговый материал: три картинки в Principled BSDF (так его понимает экспорт glTF)
    final = bpy.data.materials.new(name + "_Baked")
    final.use_nodes = True
    nt = final.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = img_col
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    t_orm = nt.nodes.new("ShaderNodeTexImage")
    t_orm.image = img_orm
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t_orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    if img_e:
        t_e = nt.nodes.new("ShaderNodeTexImage")
        t_e.image = img_e
        nt.links.new(t_e.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit_max

    # Непрозрачные грани — в общий материал, прозрачные оставляем на своих материалах
    keep = [i for i, info in enumerate(infos) if info["transparent"]]
    remap = {i: (1 + keep.index(i) if i in keep else 0) for i in range(len(infos))}
    idx = [0] * len(me.polygons)
    me.polygons.foreach_get("material_index", idx)
    me.materials.clear()
    me.materials.append(final)
    for i in keep:
        me.materials.append(originals[i])
    me.polygons.foreach_set("material_index", [remap.get(i, 0) for i in idx])
    me.update()

    scene.render.engine = old_engine
    return obj


if __name__ == "__main__":
    # Запуск из Blender на выделенной модели
    ob = bpy.context.active_object
    if ob is None or ob.type != "MESH":
        raise RuntimeError("Выдели меш-модель перед запуском")
    folder = os.path.join(os.path.dirname(bpy.data.filepath) or "/tmp", "textures_baked")
    stylize(ob, folder, SIZE_UNIT)
    print("[OK] Стилизация запечена:", folder)

# Стилизует уже готовую модель .glb (с костями и анимациями) и сохраняет новый .glb.
# Нужен для моделей, которые правились в Blender руками и уже не совпадают со своим build_*.py.
#   python stylize_glb.py <вход.glb> <выход.glb> [размер текстуры] [--plain]
# --plain — только переупаковать без стилизации (проверка, что модель не портится).
import bpy, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stylize

args = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else sys.argv[1:]
plain = "--plain" in args
args = [a for a in args if a != "--plain"]
src, dst = args[0], args[1]
size = int(args[2]) if len(args) > 2 else 0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src, bone_heuristic="BLENDER", guess_original_bind_pose=False)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
for rig in rigs:
    rig.data.pose_position = "REST"   # запекаем в позе покоя
    if rig.animation_data:
        rig.animation_data.action = None
for ob in meshes:
    if plain:
        break
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    s = size or (stylize.SIZE_BIG if tris >= 1400 else stylize.SIZE_UNIT)
    stylize.stylize(ob, os.path.join(os.path.dirname(os.path.abspath(__file__)), "baked"), s)
    print(ob.name, tris, "треугольников, текстура", s)
for rig in rigs:
    rig.data.pose_position = "POSE"

bpy.ops.object.select_all(action="SELECT")
anim = bool(bpy.data.actions)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True,
                          export_animations=anim, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_def_bones=False, export_apply=False,
                          export_yup=True)
print("OK", dst)

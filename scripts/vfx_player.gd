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
	"sporeling": "spore", "reed_lurker": "reed", "leech": "water", "drowned_captain": "block",
	"spirit_storm": "storm", "spirit_wind": "wind", "spirit_bog": "bog", "spirit_fire": "embers",
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

	# ---- Для эффектов карт (VfxCards) ----
	# След за снарядом: мелкие светящиеся точки остаются в воздухе и гаснут
	"trail": {"tex": "soft_dot", "color": C_HIT, "energy": 2.0, "amount": 40, "life": 0.35,
		"speed": [0.05, 0.3], "spread": 180.0, "gravity": 0.0, "damping": 1.0, "size": [0.1, 0.2],
		"add": true},
	# Огненный клуб — тот же лист дыма, но светится (огненный шар, взрыв огня)
	"fire_puff": {"tex": "smoke_sheet", "frames": 4, "color": Color(1.0, 0.55, 0.15, 0.9), "energy": 2.2,
		"amount": 8, "life": 0.55, "speed": [0.5, 1.6], "dir": Vector3.UP, "spread": 60.0, "gravity": 1.2,
		"damping": 2.0, "size": [0.5, 0.9], "radius": 0.2, "add": true, "spin": 60.0},
	# Тёмный дым после огня
	"smoke": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.22, 0.22, 0.24, 0.55), "amount": 6,
		"life": 1.1, "speed": [0.4, 1.0], "dir": Vector3.UP, "spread": 30.0, "gravity": 0.6, "damping": 1.0,
		"size": [0.6, 1.0], "radius": 0.25, "spin": 30.0},
	# Пар — белые клубы (смесь огня и воды)
	"steam_puff": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.92, 0.95, 1.0, 0.6), "amount": 8,
		"life": 0.9, "speed": [0.6, 1.6], "dir": Vector3.UP, "spread": 40.0, "gravity": 0.8, "damping": 1.2,
		"size": [0.6, 1.1], "radius": 0.3, "spin": 40.0},
	# Столб брызг вверх (вода по клетке)
	"splash_up": {"tex": "drop", "color": Color(0.6, 0.85, 1.0, 0.95), "energy": 1.6, "amount": 24,
		"life": 0.6, "speed": [3.0, 5.5], "dir": Vector3.UP, "spread": 25.0, "gravity": -12.0,
		"size": [0.14, 0.26], "radius": 0.3, "add": true, "stretch": true},
	# Пузыри топи — медленно всплывают, не светятся
	"bubbles": {"tex": "soft_dot", "color": Color(0.32, 0.45, 0.28, 0.85), "amount": 14, "life": 0.9,
		"speed": [0.4, 1.0], "dir": Vector3.UP, "spread": 25.0, "gravity": 0.6, "damping": 1.0,
		"size": [0.1, 0.22], "radius": 0.4},
	# Комья тины (топь)
	"mud": {"tex": "drop", "color": Color(0.22, 0.32, 0.18), "amount": 16, "life": 0.6,
		"speed": [2.0, 4.0], "dir": Vector3.UP, "spread": 40.0, "gravity": -11.0, "size": [0.14, 0.26],
		"radius": 0.3, "stretch": true},
	# Порыв ветра: длинные бледные черты, летят по направлению (aim)
	"gust": {"tex": "spark", "color": Color(0.78, 0.92, 0.82, 0.7), "energy": 1.5, "amount": 18,
		"life": 0.4, "speed": [6.0, 10.0], "spread": 14.0, "gravity": 0.0, "damping": 4.0,
		"size": [0.16, 0.3], "radius": 0.4, "add": true, "stretch": true},
	# Сухие листья камыша в ветре
	"leaves": {"tex": "shard", "color": Color(0.68, 0.66, 0.42), "amount": 8, "life": 0.7,
		"speed": [3.0, 6.0], "spread": 30.0, "gravity": -2.0, "damping": 2.5, "size": [0.08, 0.15],
		"radius": 0.4, "spin": 600.0},
	# Линии скорости за рывком (летят назад, aim)
	"speed_lines": {"tex": "spark", "color": Color(0.85, 0.85, 0.8, 0.6), "energy": 1.2, "amount": 14,
		"life": 0.3, "speed": [5.0, 8.0], "spread": 10.0, "gravity": 0.0, "damping": 3.0,
		"size": [0.14, 0.26], "radius": 0.35, "add": true, "stretch": true},
	# Подъём силы: светящиеся точки столбом вверх вокруг героя
	"rise": {"tex": "soft_dot", "color": C_HIT, "energy": 2.6, "amount": 34, "life": 0.75,
		"speed": [1.2, 2.8], "dir": Vector3.UP, "spread": 6.0, "gravity": 0.0, "damping": 1.2,
		"size": [0.18, 0.34], "radius": 0.5, "add": true},
	# Мелкие блики (магия мага, искра кристалла)
	"glints": {"tex": "glint", "color": C_MAGE, "energy": 2.5, "amount": 8, "life": 0.45,
		"speed": [0.6, 1.8], "spread": 90.0, "gravity": 0.0, "damping": 2.0, "size": [0.18, 0.32],
		"radius": 0.2, "add": true, "spin": 200.0},

	# ---- Клетки и объекты (этап 3). *_loop — непрерывные, живут, пока есть клетка ----
	# Поля: fade_in — частица появляется плавно; flat — лежит на земле (круги на воде);
	# grow — растёт до конца жизни; color_mid — цвет в середине жизни.
	# Язык пламени: из бело-жёлтого в оранжевый и в тёмный
	"fire_loop": {"tex": "flame_sheet", "frames": 4, "color": Color(1.0, 0.72, 0.3), "energy": 1.7,
		"color_mid": Color(1.0, 0.42, 0.08), "amount": 10, "life": 0.85, "speed": [0.25, 0.6], "dir": Vector3.UP,
		"spread": 8.0, "gravity": 0.6, "damping": 0.5, "size": [0.55, 0.85], "radius": 0.28, "add": true,
		"fade_in": true},
	# Угольки поднимаются над огнём
	"ember_loop": {"tex": "soft_dot", "color": Color(1.0, 0.6, 0.2), "energy": 3.0, "amount": 6, "life": 1.4,
		"speed": [0.6, 1.2], "dir": Vector3.UP, "spread": 25.0, "gravity": 0.3, "damping": 0.4,
		"size": [0.04, 0.08], "radius": 0.3, "add": true},
	# Дым над огнём
	"smoke_loop": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.16, 0.16, 0.17, 0.4), "amount": 3,
		"life": 2.2, "speed": [0.3, 0.6], "dir": Vector3.UP, "spread": 15.0, "gravity": 0.2, "damping": 0.3,
		"size": [0.5, 0.9], "radius": 0.2, "spin": 20.0, "fade_in": true, "grow": true},
	# Круги на луже
	"ripple_loop": {"tex": "ring", "color": Color(0.55, 0.8, 1.0, 0.45), "energy": 1.2, "amount": 2,
		"life": 1.8, "speed": [0.0, 0.0], "gravity": 0.0, "size": [0.45, 0.75], "radius": 0.2, "add": true,
		"flat": true, "grow": true},
	# Блики на льду
	"frost_loop": {"tex": "glint", "color": Color(0.85, 0.95, 1.0), "energy": 2.0, "amount": 3, "life": 1.3,
		"speed": [0.0, 0.05], "gravity": 0.0, "size": [0.12, 0.22], "radius": 0.4, "add": true, "spin": 60.0,
		"fade_in": true},
	# Пузыри в топи и лаве
	"bubble_loop": {"tex": "ring", "color": Color(0.35, 0.5, 0.28, 0.6), "amount": 3, "life": 1.0,
		"speed": [0.0, 0.0], "gravity": 0.0, "size": [0.12, 0.25], "radius": 0.3, "flat": true, "grow": true},
	# Ядовитые клубы газа: медленно клубятся над клеткой
	"gas_loop": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.45, 0.85, 0.25, 0.22), "energy": 1.3,
		"amount": 5, "life": 2.6, "speed": [0.05, 0.2], "dir": Vector3.UP, "spread": 60.0, "gravity": 0.05,
		"damping": 0.2, "size": [0.6, 1.0], "radius": 0.3, "spin": 25.0, "fade_in": true},
	# Пузыри и искры на лаве
	"lava_loop": {"tex": "ring", "color": Color(1.0, 0.75, 0.3), "energy": 2.5, "amount": 3, "life": 0.9,
		"speed": [0.0, 0.0], "gravity": 0.0, "size": [0.12, 0.24], "radius": 0.3, "flat": true, "grow": true,
		"add": true},

	# ---- Разовые события поля ----
	# Огненный шар взрыва: крупные светящиеся клубы
	"blast": {"tex": "smoke_sheet", "frames": 4, "color": Color(1.0, 0.75, 0.35), "energy": 3.0,
		"color_mid": Color(1.0, 0.45, 0.1), "amount": 14, "life": 0.6, "speed": [1.5, 3.5], "dir": Vector3.UP,
		"spread": 80.0, "gravity": 1.0, "damping": 3.5, "size": [0.9, 1.5], "radius": 0.35, "add": true,
		"spin": 90.0},
	# Зелёный газ после взрыва бочки
	"gas_blast": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.5, 0.9, 0.3, 0.55), "energy": 1.4,
		"amount": 10, "life": 1.3, "speed": [1.0, 2.5], "dir": Vector3.UP, "spread": 85.0, "gravity": 0.3,
		"damping": 2.0, "size": [0.8, 1.3], "radius": 0.4, "spin": 40.0},
	# Щепки (бочка, дерево, мостки)
	"splinters": {"tex": "shard", "color": Color(0.42, 0.33, 0.22), "amount": 18, "life": 0.9,
		"speed": [2.5, 5.0], "dir": Vector3.UP, "spread": 70.0, "gravity": -11.0, "size": [0.08, 0.16],
		"radius": 0.25, "spin": 700.0},
	# Ледяные осколки
	"ice_shards": {"tex": "shard", "color": Color(0.8, 0.94, 1.0), "energy": 1.6, "amount": 24, "life": 0.8,
		"speed": [2.5, 5.5], "dir": Vector3.UP, "spread": 75.0, "gravity": -10.0, "size": [0.12, 0.24],
		"radius": 0.2, "spin": 600.0, "add": true},
	# Иней: белые блики разлетаются по клетке (заморозка)
	"frost_burst": {"tex": "glint", "color": Color(0.85, 0.95, 1.0), "energy": 2.5, "amount": 14,
		"life": 0.6, "speed": [0.5, 1.5], "spread": 90.0, "gravity": 0.0, "damping": 2.0,
		"size": [0.14, 0.26], "radius": 0.35, "add": true, "spin": 200.0},

	# ---- Состояния на юнитах (этап 4), непрерывные, мелкие — модель должна быть видна ----
	# Мокрый: редкие капли падают с фигурки
	"drip_loop": {"tex": "drop", "color": Color(0.6, 0.85, 1.0, 0.9), "energy": 1.8, "amount": 10,
		"life": 0.55, "speed": [0.0, 0.3], "dir": Vector3.DOWN, "spread": 10.0, "gravity": -7.0,
		"size": [0.12, 0.18], "radius": 0.28, "add": true, "stretch": true},
	# Яд: зелёные пузырьки поднимаются
	"poison_loop": {"tex": "soft_dot", "color": C_POISON, "energy": 2.2, "amount": 7, "life": 1.1,
		"speed": [0.3, 0.6], "dir": Vector3.UP, "spread": 15.0, "gravity": 0.2, "damping": 0.3,
		"size": [0.1, 0.17], "radius": 0.3, "add": true, "fade_in": true},
	# Опутан: кольца тины у ног и клочья, что тянутся из земли
	"bind_loop": {"tex": "ring", "color": Color(0.28, 0.42, 0.22, 0.9), "amount": 2, "life": 1.4,
		"speed": [0.0, 0.0], "gravity": 0.0, "size": [0.8, 1.0], "flat": true, "fade_in": true},
	"vines_loop": {"tex": "shard", "color": Color(0.3, 0.45, 0.22), "amount": 5, "life": 0.9,
		"speed": [0.3, 0.6], "dir": Vector3.UP, "spread": 20.0, "gravity": -0.3, "damping": 0.5,
		"size": [0.1, 0.18], "radius": 0.4, "spin": 90.0, "fade_in": true},
	# Руна на оружии: огоньки цвета руны вьются у руки
	"rune_loop": {"tex": "soft_dot", "color": C_HIT, "energy": 2.8, "amount": 12, "life": 0.7,
		"speed": [0.2, 0.5], "dir": Vector3.UP, "spread": 60.0, "gravity": 0.3, "damping": 0.6,
		"size": [0.12, 0.2], "radius": 0.25, "add": true, "fade_in": true},
	# Фитиль жабы: искры и дымок
	"fuse_loop": {"tex": "spark", "color": C_FIRE, "energy": 3.0, "amount": 12, "life": 0.35,
		"speed": [1.2, 2.5], "dir": Vector3.UP, "spread": 45.0, "gravity": -5.0, "damping": 1.0,
		"size": [0.07, 0.11], "radius": 0.1, "add": true, "stretch": true},
	"fuse_smoke": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.25, 0.25, 0.26, 0.4), "amount": 3,
		"life": 1.4, "speed": [0.3, 0.6], "dir": Vector3.UP, "spread": 15.0, "gravity": 0.2,
		"size": [0.3, 0.5], "radius": 0.1, "spin": 30.0, "fade_in": true, "grow": true},

	# ---- Атмосфера (этап 6). Поле turbulence — частицы «роятся» (шум вместо прямого полёта) ----
	# Болотные огоньки над полем (область задаётся при вызове loop, параметр box)
	"wisp_loop": {"tex": "soft_dot", "color": Color(0.6, 1.0, 0.75), "energy": 2.0, "amount": 40, "life": 7.0,
		"speed": [0.05, 0.2], "dir": Vector3.UP, "spread": 60.0, "gravity": 0.0, "size": [0.12, 0.22],
		"add": true, "fade_in": true, "turbulence": 0.35},
	# Слои тумана у краёв поля: огромные бледные клубы медленно ползут
	"mist_loop": {"tex": "smoke_sheet", "frames": 4, "color": Color(0.55, 0.66, 0.6, 0.14), "amount": 12,
		"life": 14.0, "speed": [0.05, 0.15], "dir": Vector3.RIGHT, "spread": 40.0, "gravity": 0.0,
		"size": [4.0, 7.0], "spin": 4.0, "fade_in": true, "grow": true},
	# Мошкара у мёртвых деревьев
	"midge_loop": {"tex": "soft_dot", "color": Color(0.08, 0.09, 0.07, 0.9), "amount": 16, "life": 2.5,
		"speed": [0.1, 0.3], "spread": 180.0, "gravity": 0.0, "size": [0.035, 0.055], "radius": 0.35,
		"turbulence": 1.0},
	# Мотыльки у фонарей
	"moth_loop": {"tex": "soft_dot", "color": Color(1.0, 0.95, 0.8), "energy": 1.6, "amount": 4, "life": 3.0,
		"speed": [0.1, 0.3], "spread": 180.0, "gravity": 0.0, "size": [0.05, 0.08], "radius": 0.4,
		"add": true, "turbulence": 1.0},
	# Морось над полем
	"rain_loop": {"tex": "spark", "color": Color(0.72, 0.8, 0.88, 0.32), "amount": 260, "life": 0.9,
		"speed": [8.0, 10.0], "dir": Vector3.DOWN, "spread": 3.0, "gravity": -2.0, "size": [0.035, 0.055],
		"stretch": true},
	# Споры вокруг споровика
	"spore_loop": {"tex": "soft_dot", "color": Color(0.78, 0.82, 0.48, 0.75), "amount": 7, "life": 2.6,
		"speed": [0.1, 0.3], "dir": Vector3.UP, "spread": 60.0, "gravity": 0.1, "size": [0.05, 0.09],
		"radius": 0.5, "fade_in": true, "turbulence": 0.5},
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
# aim — куда направить выброс (вместо направления пресета), например вдоль удара.
func burst(preset_name: String, at: Vector3, scale: float = 1.0, amount_override: int = 0,
		color_override: Color = Color(0, 0, 0, 0), aim: Vector3 = Vector3.ZERO) -> GPUParticles3D:
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
	if aim.length() > 0.01:
		parts.basis = _basis_up_to(aim)   # «верх» выброса смотрит туда, куда надо
	if scale != 1.0:
		parts.scale = Vector3.ONE * sqrt(scale)
	add_child(parts)
	parts.emitting = true
	parts.finished.connect(parts.queue_free)
	return parts


# Поворот, при котором локальная ось Y смотрит вдоль dir
func _basis_up_to(dir: Vector3) -> Basis:
	var up: Vector3 = dir.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up).normalized())


# Непрерывный след за движущимся узлом (снаряд). Частицы остаются в мире и гаснут.
# Вернёт излучатель: потом вызвать stop_trail().
func trail(preset_name: String, follow: Node3D, color: Color) -> GPUParticles3D:
	var p: Dictionary = PRESETS[preset_name]
	var parts := GPUParticles3D.new()
	parts.amount = p.get("amount", 30) if FULL_EFFECTS else p.get("amount", 30) / 2
	parts.lifetime = p.get("life", 0.35)
	parts.local_coords = false
	parts.fixed_fps = 0
	parts.process_material = _process_for(preset_name, color)
	parts.draw_pass_1 = _draw_for(preset_name)
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 8, 16))
	follow.add_child(parts)
	parts.emitting = true
	return parts


# Материал частиц пресета с другим цветом — чтобы перекрасить уже работающий loop
func loop_material(preset_name: String, color: Color) -> ParticleProcessMaterial:
	return _process_for(preset_name, color)


# Непрерывный эффект на месте (огонь на клетке, круги на луже, газ). Живёт, пока жив parent.
# at — точка относительно parent.
# color — другой цвет (прозрачный Color — как в пресете); box — частицы появляются по всей коробке
# с такими полуразмерами (огоньки над полем, морось), а не в точке.
func loop(preset_name: String, parent: Node3D, at: Vector3 = Vector3.ZERO, scale: float = 1.0,
		color: Color = Color(0, 0, 0, 0), box: Vector3 = Vector3.ZERO) -> GPUParticles3D:
	var p: Dictionary = PRESETS[preset_name]
	var parts := GPUParticles3D.new()
	var amount: int = p.get("amount", 8)
	parts.amount = maxi(1, amount if FULL_EFFECTS else amount / 2)
	parts.lifetime = p.get("life", 1.0)
	parts.preprocess = parts.lifetime   # сразу «в разгаре», а не с пустого места
	parts.randomness = 0.3
	parts.fixed_fps = 0
	var process: ParticleProcessMaterial = _process_for(preset_name, color)
	if box != Vector3.ZERO:
		process = process.duplicate()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = box
	parts.process_material = process
	parts.draw_pass_1 = _draw_for(preset_name)
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach: Vector3 = box + Vector3(2.0, 3.0, 2.0)
	parts.visibility_aabb = AABB(-reach, reach * 2.0)
	parts.position = at
	if scale != 1.0:
		parts.scale = Vector3.ONE * scale
	parent.add_child(parts)
	parts.emitting = true
	return parts


func stop_trail(parts: GPUParticles3D) -> void:
	if parts == null or not is_instance_valid(parts):
		return
	var at: Transform3D = parts.global_transform
	parts.get_parent().remove_child(parts)
	add_child(parts)   # отцепляем от снаряда: тот удаляется, а след догорает сам
	parts.global_transform = at
	parts.emitting = false
	get_tree().create_timer(parts.lifetime + 0.1).timeout.connect(parts.queue_free)


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
	var turbulence: float = p.get("turbulence", 0.0)
	if turbulence > 0.0:
		# Шум сбивает частицы с прямого пути — рой мошкары, плавающие огоньки
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 1.0
		m.turbulence_noise_scale = 2.5
		m.turbulence_noise_speed = Vector3(0.2, 0.2, 0.2)
		m.turbulence_influence_min = turbulence * 0.5
		m.turbulence_influence_max = turbulence
	# Размер: быстро вырастает и плавно уменьшается к концу жизни
	var curve := Curve.new()
	if p.get("grow", false):
		curve.add_point(Vector2(0.0, 0.25))
		curve.add_point(Vector2(1.0, 1.0))
	else:
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
	# Цвет по жизни частицы: точки (доля жизни → цвет), записываем сразу массивами
	var offs: Array[float] = []
	var cols: Array[Color] = []
	if p.get("fade_in", false):
		offs.append(0.0)
		cols.append(Color(start.r, start.g, start.b, 0.0))
		offs.append(0.18)
		cols.append(start)
	else:
		offs.append(0.0)
		cols.append(start)
	if p.has("color_mid") and tint.a <= 0.0:
		var mid: Color = p["color_mid"]
		offs.append(0.5)
		cols.append(Color(mid.r * energy, mid.g * energy, mid.b * energy, start.a * 0.85))
		finish = Color(mid.r * energy * 0.4, mid.g * energy * 0.4, mid.b * energy * 0.4, 0.0)
	else:
		offs.append(0.6)
		cols.append(Color(start.r, start.g, start.b, start.a * 0.8))
	offs.append(1.0)
	cols.append(finish)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array(offs)
	grad.colors = PackedColorArray(cols)
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	grad_tex.use_hdr = true   # цвета ярче 1.0 — так их подхватывает свечение (glow)
	m.color_ramp = grad_tex
	_process_cache[key] = m
	return m


func _draw_for(preset_name: String) -> Mesh:
	if _draw_cache.has(preset_name):
		return _draw_cache[preset_name]
	var p: Dictionary = PRESETS[preset_name]
	if p.get("flat", false):
		# Лежит на земле: плоскость «лицом вверх», не поворачивается к камере
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.0, 1.0)
		plane.material = _make_draw_material(p)
		_draw_cache[preset_name] = plane
		return plane
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
	if p.get("flat", false):
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	else:
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
	var auras: Node = view.get_node_or_null("Auras")   # кольца состояний — не часть модели
	for n in view.find_children("*", "MeshInstance3D", true, false):
		if auras != null and auras.is_ancestor_of(n):
			continue
		out.append(n as MeshInstance3D)
	return out


# Светящийся слой поверх всех материалов фигурки (один на фигурку: вспышка урона, пульс жабы)
func _flash_material(view: Node3D) -> ShaderMaterial:
	if view.has_meta("flash_mat"):
		return view.get_meta("flash_mat")
	var mat := ShaderMaterial.new()
	mat.shader = _flash_shader
	view.set_meta("flash_mat", mat)
	for m in _meshes(view):
		m.material_overlay = mat
	return mat


# Вспышка модели при уроне: поверх всех материалов кладём светящийся слой и гасим его
func flash(view: Node3D, color: Color = C_HIT, strength: float = 1.0) -> void:
	var mat: ShaderMaterial = _flash_material(view)
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
		tame(view, height, spirit_color)
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


# ---------- Заготовки для эффектов карт (используют VfxCards) ----------

var _dome_shader: Shader = preload("res://assets/shaders/vfx/shield_dome.gdshader")
var _glow_mat_cache: Dictionary = {}   # цвет → материал светящейся ленты/шарика


# Светящийся материал (складывается с фоном) для лент, молний, шариков
func _glow_material(texture_name: String = "") -> StandardMaterial3D:
	if _glow_mat_cache.has(texture_name):
		return _glow_mat_cache[texture_name]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	if texture_name != "":
		mat.albedo_texture = load(TEX_DIR + texture_name + ".png")
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
	_glow_mat_cache[texture_name] = mat
	return mat


# Светящийся шарик-ядро (сгусток магии, огненный шар). Цвет — через vertex color квада.
func orb(color: Color, size: float, energy: float = 2.5) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# У квада нет вершинных цветов, поэтому у каждого шарика свой материал с цветом (их немного)
	var mat: StandardMaterial3D = _glow_material("soft_dot").duplicate()
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	node.material_override = mat
	# Блик поверх — звёздочка поменьше
	var star := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(size * 0.9, size * 0.9)
	star.mesh = sq
	var smat: StandardMaterial3D = mat.duplicate()
	smat.albedo_texture = load(TEX_DIR + "glint.png")
	smat.albedo_color = Color(1.0 + color.r, 1.0 + color.g, 1.0 + color.b, 1.0)
	star.material_override = smat
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(star)
	add_child(node)
	return node


# Снаряд: шарик со следом летит из from в to (по дуге высотой arc), потом исчезает.
# Ждать его через await. Возвращает, когда снаряд долетел.
func projectile(from: Vector3, to: Vector3, color: Color, size: float = 0.45, time: float = 0.22,
		arc: float = 0.3) -> void:
	var core: MeshInstance3D = orb(color, size)
	core.global_position = from
	var tr: GPUParticles3D = trail("trail", core, color)
	var tween: Tween = core.create_tween()
	tween.tween_method(func(t: float) -> void:
		var p: Vector3 = from.lerp(to, t)
		p.y += sin(t * PI) * arc
		core.global_position = p, 0.0, 1.0, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished
	stop_trail(tr)
	core.queue_free()


# Ломаная молния из from в to: ярко вспыхивает, пару раз «перещёлкивается» и гаснет.
# Вызывать без await — длится ~0,25 с.
func lightning(from: Vector3, to: Vector3, color: Color, width: float = 0.07, jags: int = 9) -> void:
	var node := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	node.mesh = mesh
	node.material_override = _glow_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var redraw := func(alpha: float) -> void:
		mesh.clear_surfaces()
		var pts: Array[Vector3] = [from]
		var dir: Vector3 = to - from
		var side: Vector3 = dir.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var fwd: Vector3 = dir.cross(side).normalized()
		for i in range(1, jags):
			var t: float = float(i) / jags
			var spread: float = dir.length() * 0.06
			pts.append(from + dir * t + side * randf_range(-spread, spread) + fwd * randf_range(-spread, spread))
		pts.append(to)
		# Две полосы: широкое мягкое свечение и тонкая яркая сердцевина
		for pass_i in 2:
			var w: float = width * (3.0 if pass_i == 0 else 1.0)
			var c: Color = color * (0.9 if pass_i == 0 else 3.0)
			c.a = alpha * (0.35 if pass_i == 0 else 1.0)
			if pass_i == 1:
				c = Color(1.0 + color.r * 2.0, 1.0 + color.g * 2.0, 1.0 + color.b * 2.0, alpha)
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for i in pts.size():
				var a: Vector3 = pts[maxi(i - 1, 0)]
				var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
				var to_cam: Vector3 = (cam.global_position - pts[i]).normalized() if cam != null else Vector3.UP
				var perp: Vector3 = (b - a).cross(to_cam).normalized() * w
				mesh.surface_set_color(c)
				mesh.surface_add_vertex(pts[i] - perp)
				mesh.surface_set_color(c)
				mesh.surface_add_vertex(pts[i] + perp)
			mesh.surface_end()
	redraw.call(1.0)
	var tween: Tween = node.create_tween()
	tween.tween_interval(0.06)
	tween.tween_callback(func() -> void: redraw.call(1.0))
	tween.tween_interval(0.06)
	tween.tween_method(func(a: float) -> void: redraw.call(a), 1.0, 0.0, 0.14)
	tween.tween_callback(node.queue_free)


# Дуга-след удара оружием: светящийся серп проносится вокруг center.
# facing — куда смотрит удар (в плоскости земли), sweep — ширина размаха в градусах
# (360 — круговой удар), radius — радиус, height — высота над землёй.
func slash(center: Vector3, facing: Vector3, color: Color, radius: float = 0.95, sweep: float = 140.0,
		time: float = 0.18, height: float = 0.85, thickness: float = 0.45) -> void:
	var node := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	node.mesh = mesh
	node.material_override = _glow_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = center + Vector3(0.0, height, 0.0)
	add_child(node)
	var f: Vector3 = Vector3(facing.x, 0.0, facing.z)
	if f.length() < 0.01:
		f = Vector3.FORWARD
	var base_angle: float = atan2(f.x, f.z)
	var half: float = deg_to_rad(sweep) * 0.5
	var tail: float = deg_to_rad(minf(sweep, 150.0))   # длина светящегося хвоста
	var segs: int = 24
	var draw_at := func(progress: float, fade: float) -> void:
		mesh.clear_surfaces()
		var head: float = -half + deg_to_rad(sweep) * progress
		# Два слоя: широкое цветное свечение и узкая почти белая кромка по внешнему краю
		for layer in 2:
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for i in segs + 1:
				var k: float = float(i) / segs          # 0 — конец хвоста, 1 — голова
				var a: float = base_angle + head - tail * (1.0 - k)
				if a - base_angle < -half - 0.01:
					a = base_angle - half
				var dir := Vector3(sin(a), 0.0, cos(a))
				# Чуть наклоняем серп: голова выше хвоста — удар выглядит живее
				var lift := Vector3(0.0, (k - 0.5) * 0.25, 0.0)
				var w: float = thickness * (0.25 + 0.75 * k)
				var inner: float = radius - w * 0.7
				var outer: float = radius + w * 0.3
				var c: Color
				if layer == 0:
					c = Color(color.r * 1.4, color.g * 1.4, color.b * 1.4, k * fade * 0.85)
				else:
					inner = radius + w * 0.05
					c = Color(0.6 + color.r * 1.6, 0.6 + color.g * 1.6, 0.6 + color.b * 1.6, k * k * fade)
				mesh.surface_set_color(Color(c.r, c.g, c.b, 0.0) if layer == 0 else c)
				mesh.surface_add_vertex(dir * inner + lift)
				mesh.surface_set_color(c)
				mesh.surface_add_vertex(dir * outer + lift)
			mesh.surface_end()
	var tween: Tween = node.create_tween()
	tween.tween_method(func(t: float) -> void: draw_at.call(t, 1.0), 0.0, 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(func(t: float) -> void: draw_at.call(1.0, t), 1.0, 0.0, 0.15)
	tween.tween_callback(node.queue_free)


# Купол щита над фигуркой: раскрывается, держится миг и тает
func dome(at: Vector3, color: Color, radius: float = 0.75, time: float = 0.55) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.is_hemisphere = true
	sphere.radial_segments = 24
	sphere.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = _dome_shader
	mat.set_shader_parameter("color", color)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.scale = Vector3(radius * 0.4, radius * 0.4 * 1.5, radius * 0.4)
	add_child(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector3(radius, radius * 1.5, radius), 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(time * 0.4)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v), 1.0, 0.0, time * 0.6)
	tween.tween_callback(node.queue_free)


# ---------- Клетки, объекты и реакции (этап 3) ----------

const SCORCH_TIME: float = 12.0   # сколько секунд держится выжженное пятно после взрыва


# Выжженное пятно на плитах (декаль — картинка, которая ложится на всё под ней). Потом тает.
func scorch(at: Vector3, size: float = 1.8) -> void:
	var decal := Decal.new()
	decal.texture_albedo = load(TEX_DIR + "scorch.png")
	decal.size = Vector3(size, 0.4, size)   # невысокая коробка: ложится на плиты, почти не пачкает фигурки
	decal.position = at + Vector3(0.0, 0.05, 0.0)
	decal.rotation.y = randf() * TAU
	add_child(decal)
	var tween: Tween = decal.create_tween()
	tween.tween_interval(SCORCH_TIME)
	tween.tween_property(decal, "modulate:a", 0.0, 2.0)
	tween.tween_callback(decal.queue_free)


# Взрыв (бочка, жаба, бомба): огненный шар, ударная волна, свет, пятно копоти.
# center — середина взрыва, gas — бочка с газом (добавить зелёный дым и щепки).
func explosion(center: Vector3, radius_cells: float = 1.0, gas: bool = false) -> void:
	var k: float = 0.8 + 0.4 * radius_cells
	burst("blast", center + Vector3(0, 0.4, 0), k)
	burst("embers", center + Vector3(0, 0.6, 0), 1.6 * k)
	burst("smoke", center + Vector3(0, 0.8, 0), 1.5 * k)
	ring(center + Vector3(0, 0.06, 0), C_FIRE, 3.2 * k, 0.4, 2.5)
	ring(center + Vector3(0, 0.06, 0), Color(1, 1, 1), 2.2 * k, 0.25, 1.5)
	light_flash(center + Vector3(0, 1.0, 0), C_FIRE, 6.0, 7.0, 0.45)
	if gas:
		burst("gas_blast", center + Vector3(0, 0.5, 0), k)
		burst("splinters", center + Vector3(0, 0.4, 0), k)
	scorch(center, 1.6 * k)


# Дерево упало: пыль и щепки по линии падения (по очереди от корня к макушке)
func tree_fall(cells: Array[Vector3]) -> void:
	for i in cells.size():
		var at: Vector3 = cells[i]
		var t: SceneTreeTimer = get_tree().create_timer(0.05 * i)
		t.timeout.connect(func() -> void:
			burst("dust", at + Vector3(0, 0.2, 0), 1.6)
			burst("splinters", at + Vector3(0, 0.3, 0), 0.6)
			ring(at + Vector3(0, 0.05, 0), Color(0.75, 0.7, 0.6), 1.6, 0.35, 0.8))


# Облако газа выпущено на клетки
func gas_cloud(cells: Array[Vector3]) -> void:
	for at in cells:
		burst("gas_blast", at + Vector3(0, 0.3, 0), 0.7)


# Реакция стихий на клетке (kind — как в сигнале BattleLogic.reaction)
func reaction(at: Vector3, kind: String) -> void:
	var up: Vector3 = at + Vector3(0, 0.3, 0)
	match kind:
		"steam":
			burst("steam_puff", up, 1.6)
			ring(at + Vector3(0, 0.05, 0), Color(0.9, 0.95, 1.0), 2.0, 0.35, 1.5)
		"freeze":
			burst("frost_burst", up)
			burst("ice_shards", up, 0.5)
			ring(at + Vector3(0, 0.05, 0), Color(0.8, 0.94, 1.0), 1.6, 0.4, 2.0)
		"shatter":
			burst("ice_shards", up, 1.4)
			burst("frost_burst", up, 0.8)
			light_flash(up, Color(0.8, 0.94, 1.0), 2.0, 3.0, 0.2)
		"lava":
			burst("blast", up, 0.7)
			burst("embers", up + Vector3(0, 0.3, 0), 1.4)
			burst("smoke", up + Vector3(0, 0.5, 0), 1.0)
			light_flash(up, C_FIRE, 3.0, 4.0, 0.3)
		"crust":
			burst("steam_puff", up, 1.2)
			burst("smoke", up + Vector3(0, 0.3, 0), 0.8)
		"shock":
			burst("shock", up + Vector3(0, 0.5, 0), 1.2, 0, C_SHOCK)
			light_flash(up, C_SHOCK, 2.0, 3.0, 0.15)
		"pincer":
			ring(at + Vector3(0, 0.06, 0), Color(0.95, 0.75, 0.35), 1.6, 0.3, 2.0)


# Столкновение: толкнули в преграду или в другого
func bump(at: Vector3, strong: bool = false) -> void:
	var k: float = 1.4 if strong else 1.0
	ring(at + Vector3(0, 0.06, 0), Color(0.9, 0.88, 0.8), 1.8 * k, 0.3, 1.6)
	burst("dust", at + Vector3(0, 0.25, 0), 1.3 * k)
	burst("sparks", at + Vector3(0, 0.7, 0), k)


# Объект сломан: мостки (щепки и всплеск), камыш сгорел (огонь и пепел), глыба льда (осколки)
func object_broken(at: Vector3, kind: String) -> void:
	match kind:
		"planks":
			burst("splinters", at + Vector3(0, 0.2, 0), 0.8)
			burst("splash", at + Vector3(0, 0.1, 0), 0.8)
			ring(at + Vector3(0, 0.05, 0), Color(0.6, 0.8, 0.75), 1.4, 0.6, 0.9)
		"reeds":
			burst("fire_puff", at + Vector3(0, 0.3, 0), 1.2)
			burst("ash", at + Vector3(0, 0.6, 0), 0.8)
			burst("embers", at + Vector3(0, 0.6, 0), 1.2)
		"ice":
			burst("ice_shards", at + Vector3(0, 0.5, 0), 1.2)
			burst("frost_burst", at + Vector3(0, 0.5, 0), 0.7)
		"stakes":
			burst("splinters", at + Vector3(0, 0.4, 0), 0.8)
			burst("embers", at + Vector3(0, 0.6, 0), 0.8)


# Мерцание света огня: свет «дышит», пока жив
func flicker(light: OmniLight3D, base: float) -> void:
	var tween: Tween = light.create_tween().set_loops()
	tween.tween_property(light, "light_energy", base * 1.25, randf_range(0.08, 0.16))
	tween.tween_property(light, "light_energy", base * 0.8, randf_range(0.08, 0.2))
	tween.tween_property(light, "light_energy", base, randf_range(0.1, 0.2))


# ---------- Состояния на юнитах (этап 4) ----------

# Цвет руны на оружии по её виду (BattleUnit.rune)
const RUNE_COLORS: Dictionary[String, Color] = {
	"fire": C_FIRE, "storm": C_SHOCK, "rot": Color(0.45, 0.7, 0.3), "tide": C_WATER,
}
const C_TAUNT := Color(0.95, 0.7, 0.3)   # провокация — тёмно-жёлтое кольцо Рыцаря


# Включает и выключает постоянные эффекты на фигурке по её состоянию.
# state — словарь из BattleLogic.snapshot (wet, poison, entangled, rune, rune_hits, taunt,
# inflation, fuse, smoldering). Эффекты живут в узле "Auras" внутри фигурки и ходят вместе с ней.
func set_auras(view: Node3D, height: float, state: Dictionary) -> void:
	var holder: Node3D = view.get_node_or_null("Auras")
	if holder == null:
		holder = Node3D.new()
		holder.name = "Auras"
		view.add_child(holder)
	var want: Dictionary = {}   # имя ауры → нужна ли
	want["wet"] = state.get("wet", 0) > 0
	want["poison"] = state.get("poison", 0) > 0
	want["bound"] = state.get("entangled", 0) > 0
	want["rune"] = state.get("rune", "") != "" and state.get("rune_hits", 0) > 0
	want["taunt"] = state.get("taunt", false)
	want["fuse"] = state.get("fuse", 0) > 0 or state.get("smoldering", false)
	for key: String in want:
		var node: Node3D = holder.get_node_or_null(key)
		if key == "rune" and node != null and want[key] and node.get_meta("kind", "") != state.get("rune", ""):
			_fade_aura(node)   # руна сменилась — другой цвет
			node = null
		if want[key] and node == null:
			node = Node3D.new()
			node.name = key
			holder.add_child(node)
			_build_aura(key, node, height, state)
		elif not want[key] and node != null:
			_fade_aura(node)
	# Руна слабеет с каждым зарядом: меньше огоньков
	var rune_node: Node3D = holder.get_node_or_null("rune")
	if rune_node != null and rune_node.get_child_count() > 0 and rune_node.get_child(0) is GPUParticles3D:
		var parts: GPUParticles3D = rune_node.get_child(0)
		parts.amount_ratio = clampf(0.35 + 0.22 * state.get("rune_hits", 0), 0.35, 1.0)
	# Раздувание жабы: мешок пульсирует бирюзой тем сильнее, чем больше стаков
	_set_inflation_pulse(view, state.get("inflation", 0))


func _build_aura(key: String, node: Node3D, height: float, state: Dictionary) -> void:
	match key:
		"wet":
			loop("drip_loop", node, Vector3(0.0, height * 0.75, 0.0))
		"poison":
			loop("poison_loop", node, Vector3(0.0, height * 0.35, 0.0))
		"bound":
			loop("bind_loop", node, Vector3(0.0, 0.05, 0.0))
			loop("vines_loop", node, Vector3(0.0, 0.1, 0.0))
		"rune":
			node.set_meta("kind", state.get("rune", ""))
			var rune_color: Color = RUNE_COLORS.get(state.get("rune", ""), C_HIT)
			var parts: GPUParticles3D = loop("rune_loop", node, Vector3(0.0, height * 0.55, 0.0))
			parts.process_material = _process_for("rune_loop", rune_color)
			# Мягкий отсвет руны на доспехе
			var glow := OmniLight3D.new()
			glow.light_color = rune_color
			glow.light_energy = 0.9
			glow.omni_range = 1.6
			glow.position.y = height * 0.55
			node.add_child(glow)
			flicker(glow, 0.9)
		"taunt":
			# Тусклое кольцо на земле, медленно вращается
			var plane := PlaneMesh.new()
			plane.size = Vector2(1.5, 1.5)
			var ring_node := MeshInstance3D.new()
			ring_node.mesh = plane
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			mat.albedo_texture = load(TEX_DIR + "ring.png")
			mat.albedo_color = Color(C_TAUNT.r * 1.4, C_TAUNT.g * 1.4, C_TAUNT.b * 1.4, 0.8)
			ring_node.material_override = mat
			ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ring_node.position.y = 0.06
			node.add_child(ring_node)
			var tween: Tween = ring_node.create_tween().set_loops()
			tween.tween_property(mat, "albedo_color:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
			tween.tween_property(mat, "albedo_color:a", 0.8, 0.8).set_trans(Tween.TRANS_SINE)
		"fuse":
			loop("fuse_loop", node, Vector3(0.0, height * 0.9, 0.0))
			loop("fuse_smoke", node, Vector3(0.0, height * 0.95, 0.0))
			var light := OmniLight3D.new()
			light.light_color = C_FIRE
			light.light_energy = 0.8
			light.omni_range = 1.8
			light.position.y = height * 0.9
			node.add_child(light)
			flicker(light, 0.8)


# Аура больше не нужна: частицы перестают появляться и догорают, потом узел удаляется
func _fade_aura(node: Node3D) -> void:
	node.name = "fading_%d" % node.get_instance_id()   # чтобы на её место можно было сразу поставить новую
	var longest: float = 0.3
	for child in node.get_children():
		if child is GPUParticles3D:
			child.emitting = false
			longest = maxf(longest, child.lifetime)
		elif child is MeshInstance3D or child is Light3D:
			var tween: Tween = child.create_tween()
			tween.tween_property(child, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	get_tree().create_timer(longest + 0.1).timeout.connect(node.queue_free)


# Убрать все ауры (фигурка погибла)
func clear_auras(view: Node3D) -> void:
	var holder: Node3D = view.get_node_or_null("Auras")
	if holder != null:
		for child in holder.get_children():
			_fade_aura(child)
	_set_inflation_pulse(view, 0)


# Пульс раздувания: поверх модели мерцает бирюза (тот же слой, что и вспышка урона)
func _set_inflation_pulse(view: Node3D, stacks: int) -> void:
	var old: Tween = view.get_meta("pulse_tween") if view.has_meta("pulse_tween") else null
	var old_stacks: int = view.get_meta("pulse_stacks", 0)
	if stacks == old_stacks:
		return
	view.set_meta("pulse_stacks", stacks)
	if old != null and old.is_valid():
		old.kill()
	view.remove_meta("pulse_tween")
	if stacks <= 0:
		return
	var mat: ShaderMaterial = _flash_material(view)
	var peak: float = 0.3 * stacks
	var pulse := func(v: float) -> void:
		mat.set_shader_parameter("flash_color", C_RIFT)   # после вспышки урона цвет снова бирюзовый
		mat.set_shader_parameter("amount", v)
	var tween: Tween = view.create_tween().set_loops()
	tween.tween_method(pulse, 0.0, peak, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_method(pulse, peak, 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	view.set_meta("pulse_tween", tween)


# ---------- Враги и духи (этап 5) ----------

const C_RITUAL := Color(0.85, 0.88, 0.8)    # ритуал — бледный мёртвый свет


# Призыв: в земле открывается бирюзовый разрыв, из него поднимаются огоньки
func summon(at: Vector3) -> void:
	var ground: Vector3 = at + Vector3(0.0, 0.06, 0.0)
	var side: Vector3 = _camera_right() * 0.55
	lightning(ground - side, ground + side, C_RIFT, 0.06, 7)   # трещина по земле
	ring(ground, C_RIFT, 1.8, 0.45, 2.5)
	burst("rift_motes", at + Vector3(0.0, 0.2, 0.0), 1.0)
	light_flash(at + Vector3(0.0, 0.6, 0.0), C_RIFT, 2.5, 3.5, 0.4)


# Круг ритуала под ритуалистом: бледный свет, к призыву ярче и шире.
# progress: 0 — только начался, 1 — призыв в этом раунде; < 0 — убрать круг.
func set_ritual(view: Node3D, progress: float) -> void:
	var holder: Node3D = view.get_node_or_null("Auras")
	if holder == null:
		holder = Node3D.new()
		holder.name = "Auras"
		view.add_child(holder)
	var node: Node3D = holder.get_node_or_null("ritual")
	if progress < 0.0:
		if node != null:
			_fade_aura(node)
		return
	if node == null:
		node = Node3D.new()
		node.name = "ritual"
		holder.add_child(node)
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.0, 1.0)
		var circle := MeshInstance3D.new()
		circle.name = "circle"
		circle.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.albedo_texture = load(TEX_DIR + "ring.png")
		circle.material_override = mat
		circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		circle.position.y = 0.07
		node.add_child(circle)
		var spin: Tween = circle.create_tween().set_loops()
		spin.tween_property(circle, "rotation:y", TAU, 6.0).from(0.0)
		var motes: GPUParticles3D = loop("rise", node, Vector3(0.0, 0.1, 0.0), 0.7)
		motes.name = "motes"
		motes.process_material = _process_for("rise", C_RITUAL)
	var c: MeshInstance3D = node.get_node("circle")
	var m: StandardMaterial3D = c.material_override
	var e: float = 0.45 + 0.75 * progress   # бледный, к призыву — ярче (но не «прожектор»)
	m.albedo_color = Color(C_RITUAL.r * e, C_RITUAL.g * e, C_RITUAL.b * e, 0.3 + 0.45 * progress)
	var size: float = 1.3 + 0.7 * progress
	c.create_tween().tween_property(c, "scale", Vector3(size, 1.0, size), 0.3)
	var p: GPUParticles3D = node.get_node("motes")
	p.amount_ratio = clampf(0.15 + 0.85 * progress, 0.1, 1.0)


# Шаман поглощает магию: от героя к его осколку тянется струйка огоньков, шаман вспыхивает бирюзой.
# Ждать через await (~0,5 с).
func absorb(from: Vector3, shaman: Node3D, height: float) -> void:
	var to: Vector3 = shaman.global_position + Vector3(0.0, height * 1.05, 0.0)
	for i in 4:
		var start: Vector3 = from + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2))
		projectile(start, to, C_MAGE.lerp(C_RIFT, 0.5), 0.22, 0.32, 0.6 + 0.2 * i)
		await get_tree().create_timer(0.06).timeout
	await get_tree().create_timer(0.28).timeout
	flash(shaman, C_RIFT, 1.0)
	burst("glints", to, 1.2, 0, C_RIFT)
	ring(shaman.global_position + Vector3(0.0, 0.06, 0.0), C_RIFT, 1.8, 0.4, 2.0)
	light_flash(to, C_RIFT, 2.0, 3.0, 0.3)


# Наследие венца: бледный огонёк летит от павшего послушника к культисту, тот вспыхивает
func bequest(from: Vector3, heir: Node3D, height: float) -> void:
	var to: Vector3 = heir.global_position + Vector3(0.0, height + 0.1, 0.0)
	await projectile(from + Vector3(0.0, 0.8, 0.0), to, C_ASH, 0.35, 0.45, 0.9)
	flash(heir, C_ASH, 0.9)
	burst("ash", to, 0.6)
	ring(heir.global_position + Vector3(0.0, 0.06, 0.0), C_ASH, 1.6, 0.4, 1.6)


# Броня корягача сгорела: кора отслаивается с угольками
func armor_burn(view: Node3D, height: float) -> void:
	var body: Vector3 = view.global_position + Vector3(0.0, height * 0.55, 0.0)
	burst("splinters", body, 1.4, 0, Color(0.35, 0.27, 0.18))
	burst("embers", body, 1.8)
	burst("fire_puff", body, 0.8)
	flash(view, C_FIRE, 1.0)
	light_flash(body, C_FIRE, 2.5, 3.5, 0.35)


# Покорение духа: бирюзовые трещины вспыхивают и гаснут, дух загорается чистым цветом стихии
# и растворяется (уходит к герою)
func tame(view: Node3D, height: float, color: Color) -> void:
	var at: Vector3 = view.global_position + Vector3(0.0, height * 0.5, 0.0)
	var mat: ShaderMaterial = _flash_material(view)
	var tween: Tween = view.create_tween()
	# Бирюза Раскола разгорается…
	tween.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("flash_color", C_RIFT)
		mat.set_shader_parameter("amount", v), 0.0, 1.0, 0.25)
	# …и перетекает в чистый цвет стихии
	tween.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("flash_color", C_RIFT.lerp(color, v))
		mat.set_shader_parameter("amount", 1.0), 0.0, 1.0, 0.35)
	tween.tween_callback(func() -> void:
		burst("rise", at - Vector3(0.0, height * 0.4, 0.0), 1.6, 0, color)
		burst("glints", at, 1.5, 0, color)
		ring(view.global_position + Vector3(0.0, 0.06, 0.0), color, 3.0, 0.6, 2.5)
		light_flash(at, color, 4.0, 5.0, 0.6)
		dissolve(view, color, height))
	burst("rift_motes", at, 1.0)   # последние искры Раскола уходят вверх


# Огоньки прирученных духов у плеча героя: маленький шарик цвета стихии с хвостиком
# облетает плечо. ids — id духов (tide, storm, wind, bog, fire), цвет берётся из их SpiritData.
func add_companions(view: Node3D, ids: Array[String], height: float) -> void:
	var holder: Node3D = view.get_node_or_null("Auras")
	if holder == null:
		holder = Node3D.new()
		holder.name = "Auras"
		view.add_child(holder)
	for i in ids.size():
		var id: String = ids[i]
		if holder.has_node("spirit_" + id):
			continue
		var color: Color = C_HIT
		var data_path: String = "res://resources/spirits/%s.tres" % id
		if ResourceLoader.exists(data_path):
			color = load(data_path).color
		var pivot := Node3D.new()
		pivot.name = "spirit_" + id
		pivot.position = Vector3(0.0, height * 0.9, 0.0)
		holder.add_child(pivot)
		var core: MeshInstance3D = orb(color, 0.2, 2.6)
		core.reparent(pivot, false)
		core.position = Vector3(0.45, 0.0, 0.0)
		var tr: GPUParticles3D = trail("trail", core, color)
		tr.amount_ratio = 0.4
		# Облёт плеча: у каждого духа своя фаза; лёгкое покачивание вверх-вниз
		var phase: float = TAU * float(i) / maxf(1.0, ids.size())
		pivot.rotation.y = phase
		var spin: Tween = pivot.create_tween().set_loops()
		spin.tween_property(pivot, "rotation:y", phase + TAU, 4.5).from(phase)
		var bob: Tween = core.create_tween().set_loops()
		bob.tween_property(core, "position:y", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
		bob.tween_property(core, "position:y", -0.08, 0.9).set_trans(Tween.TRANS_SINE)


# ---------- Атмосфера (этап 6) ----------

# Постоянный эффект у врага: споры у споровика (на фигурке, ходит с ней)
func enemy_ambient(view: Node3D, enemy_id: String, height: float) -> void:
	if enemy_id != "sporeling":
		return
	var holder: Node3D = view.get_node_or_null("Auras")
	if holder == null:
		holder = Node3D.new()
		holder.name = "Auras"
		view.add_child(holder)
	var node := Node3D.new()
	node.name = "spores"
	holder.add_child(node)
	loop("spore_loop", node, Vector3(0.0, height * 0.6, 0.0))

class_name UnitPlate
extends Control
# Плашка над фигуркой на поле: полоса здоровья с числом, щиток блока,
# а у врага ещё и намерение — значок удара и урон в этом раунде.
# Рисуется в 2D поверх 3D-сцены; на место её ставит фигурка (scripts/unit.gd).
# Сама ничего не считает: что показать, ей передают словарём через set_info().

const PLATE_SIZE := Vector2(76, 38)
const BAR_RECT := Rect2(15, 25, 46, 12)
const COLOR_FIRE_WARN := Color(1.0, 0.62, 0.2)   # оранжевый: красный занят угрозой врагов
const COLOR_WET := Color(0.5, 0.78, 1.0)         # «Мокрый»: голубая капля
const COLOR_POISON := Color(0.72, 0.92, 0.25)    # «Яд»: ядовитый жёлто-зелёный, как газ в бочках

const PREVIEW_MARKS: Dictionary = {   # новое состояние -> [значок, цвет]
	"wet": ["drop", COLOR_WET], "poison": ["poison", COLOR_POISON], "entangled": ["entangled", Color(0.9, 0.9, 0.85)],
	"rust": ["drain", Color(0.9, 0.9, 0.85)], "stunned": ["bolt", Color(0.9, 0.9, 0.85)],
	"brand": ["target", Color(0.9, 0.9, 0.85)],
}

var _info: Dictionary = {}
var _preview: Dictionary = {}   # предпросмотр карты: что станет с юнитом (пусто — не показывать)


func _init() -> void:
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # клики проходят сквозь плашку на поле
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)


# info — словарь из Battle._plate_info():
#   hp, max_hp, block, is_hero, color (цвет героя),
#   intent_icon (имя иконки или ""), intent_value (урон, 0 — не писать), intent_color,
#   marks — список имён иконок-состояний (опутан, провокация…),
#   fire — сколько урона от огня юнит получит в конце хода врагов (прогноз; 0 — не писать)
func set_info(info: Dictionary) -> void:
	_info = info
	queue_redraw()


# Предпросмотр карты (BattleLogic.preview_card, запись units[id]): hp_after, block, block_after,
# killed, new — новые состояния. Пустой словарь — убрать. Пока показан, плашка мигает.
func set_preview(preview: Dictionary) -> void:
	_preview = preview
	set_process(not preview.is_empty())
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()   # мигание «призрачной» части полосы


func _draw() -> void:
	if _info.is_empty():
		return
	var font: Font = UiKit.font_bold()
	var hp: int = _info["hp"]
	var max_hp: int = maxi(_info["max_hp"], 1)
	var is_hero: bool = _info["is_hero"]

	# --- Полоса здоровья ---
	var frame: Color = (_info["color"] as Color).lightened(0.2) if is_hero else Color(0, 0, 0, 0.9)
	draw_rect(BAR_RECT.grow(1.5), frame)
	draw_rect(BAR_RECT, Color(0.03, 0.04, 0.04))
	var fill := BAR_RECT
	fill.size.x = BAR_RECT.size.x * clampf(float(hp) / max_hp, 0.0, 1.0)
	draw_rect(fill, UiKit.HP if is_hero else UiKit.hp_enemy())
	_text(font, str(hp), BAR_RECT.position + Vector2(0, 10.5), BAR_RECT.size.x, 11, Color.WHITE)
	var pulse: float = 0.55 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	if not _preview.is_empty():
		# Сколько здоровья уйдёт: мигающая светлая часть полосы и число справа.
		# Своим героям — оранжевым предупреждением (красный занят угрозой врагов).
		var after: int = clampi(_preview["hp_after"], 0, max_hp)
		var seg := BAR_RECT
		if after < hp:
			seg.position.x += BAR_RECT.size.x * float(after) / max_hp
			seg.size.x = BAR_RECT.size.x * float(hp - after) / max_hp
			draw_rect(seg, Color(1.0, 0.96, 0.85, 0.85 * pulse))
		elif after > hp:
			seg.position.x += BAR_RECT.size.x * float(hp) / max_hp
			seg.size.x = BAR_RECT.size.x * float(after - hp) / max_hp
			draw_rect(seg, Color(UiKit.HP, 0.85 * pulse))   # лечение
		if after != hp:
			var txt: String = ("-%d" % (hp - after)) if after < hp else ("+%d" % (after - hp))
			var col: Color = (COLOR_FIRE_WARN if is_hero else Color(1.0, 0.95, 0.85)) if after < hp else UiKit.HP
			_text(font, txt, Vector2(BAR_RECT.end.x + 4, BAR_RECT.position.y + 11), -1, 14, col, 4, HORIZONTAL_ALIGNMENT_LEFT)
		if _preview.get("killed", false):
			draw_rect(BAR_RECT.grow(3.5), Color(UiKit.BRASS, 0.6 + 0.4 * pulse), false, 2.0)   # падёт

	# --- Блок: щиток слева на полосе, число внутри ---
	var block: int = _info["block"]
	if block > 0:
		var shield := Rect2(BAR_RECT.position.x - 13, BAR_RECT.position.y - 5, 21, 21)
		draw_texture_rect(UiKit.icon("shield"), shield.grow(1.5), false, Color(0, 0, 0, 0.9))
		draw_texture_rect(UiKit.icon("shield"), shield, false, UiKit.BLOCK)
		_text(font, str(block), shield.position + Vector2(0, 14.5), shield.size.x, 11, Color(0.05, 0.08, 0.12), 0)
		if not _preview.is_empty() and int(_preview.get("block_after", block)) < block:
			draw_texture_rect(UiKit.icon("shield"), shield, false, Color(1, 1, 1, 0.7 * pulse))   # блок съедят

	# --- Верхний ряд: намерение врага и значки состояний ---
	var parts: Array[Array] = []   # [иконка, цвет, число-текст]
	var intent_icon: String = _info.get("intent_icon", "")
	if intent_icon != "":
		var value: int = _info.get("intent_value", 0)
		parts.append([intent_icon, _info.get("intent_color", UiKit.threat()), str(value) if value > 0 else ""])
	# Прогноз: к концу хода врагов юнит будет стоять в огне — сколько он потеряет
	var fire: int = _info.get("fire", 0)
	if fire > 0:
		parts.append(["fire", COLOR_FIRE_WARN, "-%d" % fire])
	for mark: String in _info.get("marks", []):
		if mark == "wet":
			parts.append(["drop", COLOR_WET, ""])
		elif mark == "poison":
			# Яд: столько урона юнит получит в конце раунда
			parts.append(["poison", COLOR_POISON, "-%d" % BattleLogic.POISON_DAMAGE])
		elif mark == "ritual":
			# Ритуал: через сколько раундов ритуалист призовёт подмогу (это угроза — красный)
			parts.append(["ritual", UiKit.threat(), str(_info.get("ritual_turns", 0))])
		elif mark.begins_with("mod_on:"):
			parts.append([mark.trim_prefix("mod_on:"), UiKit.RIFT.lightened(0.25), ""])   # модификатор сработал
		elif mark.begins_with("mod:"):
			parts.append([mark.trim_prefix("mod:"), Color(UiKit.RIFT, 0.55), ""])   # модификатор ждёт условия
		elif mark.begins_with("num:"):
			var bits: PackedStringArray = mark.split(":")   # "num:значок:число"
			parts.append([bits[1], UiKit.TEXT, bits[2] if bits.size() > 2 else ""])
		elif mark.begins_with("ai_"):
			parts.append([mark, UiKit.TEXT_DIM, ""])   # характер врага — серый: бирюза занята усилениями
		else:
			parts.append([mark, UiKit.TEXT, ""])
	# Предпросмотр: состояния, которые появятся от карты, — полупрозрачные и мигают
	for key: String in _preview.get("new", []):
		var add: Array = PREVIEW_MARKS.get(key, [])
		if not add.is_empty():
			var col: Color = add[1]
			parts.append([add[0], Color(col, 0.35 + 0.45 * pulse), ""])
	var width: float = 0.0
	for part: Array in parts:
		width += 17.0
		if part[2] != "":
			width += font.get_string_size(part[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 2.0
		width += 3.0
	var x: float = (PLATE_SIZE.x - width) / 2.0
	for part: Array in parts:
		var icon_rect := Rect2(x, 3, 17, 17)
		draw_texture_rect(UiKit.icon(part[0]), icon_rect.grow(1.5), false, Color(0, 0, 0, 0.85))
		draw_texture_rect(UiKit.icon(part[0]), icon_rect, false, part[1])
		x += 17.0
		if part[2] != "":
			var text_width: float = font.get_string_size(part[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			_text(font, part[2], Vector2(x + 2.0, 17.5), -1, 15, Color.WHITE, 5, HORIZONTAL_ALIGNMENT_LEFT)
			x += text_width + 2.0
		x += 3.0


# Надпись с тёмной обводкой, чтобы читалась на любом фоне
func _text(font: Font, text: String, pos: Vector2, width: float, font_size: int, color: Color,
		outline: int = 4, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if outline > 0:
		draw_string_outline(font, pos, text, align, width, font_size, outline, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, align, width, font_size, color)

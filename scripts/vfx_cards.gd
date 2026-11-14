class_name VfxCards
extends RefCounted
# Эффекты розыгрыша карт (ТЗ claude/тз-эффекты.md, этап 2).
# У каждой карты есть «форма» эффекта (как он летит и бьёт) и «цвет» (стихия или герой).
# Форма и цвет подбираются сами по полям карты (pick), а поле vfx в карте может их задать вручную:
# "area:fire", "bolt", ":water" (только цвет).
#
# Формы:
#   melee — удар оружием: светящийся серп (дуга, круг), искры на клетках
#   bash  — толчок/пинок: ударная волна-кольцо, пыль, линии скорости
#   staff — удар посохом мага: короткая фиолетовая дуга и блики
#   dash  — рывок, таран, прыжок: пыль, линии скорости, удар при приземлении
#   guard — блок: купол щита над героем
#   buff  — усиление: столб огоньков вверх, кольцо
#   bolt  — снаряд в цель (у молнии — разряд с неба)
#   chain — цепная молния: прыгает от цели к цели
#   wave  — по линии клеток по очереди
#   area  — по области: снаряд в центр и всплеск на каждой клетке
# Цвета: steel, rage, arcane, water, lightning, wind, bog, fire, steam.

const TINTS: Dictionary[String, Color] = {
	"steel": Color(0.78, 0.86, 0.96),
	"rage": Color(0.95, 0.7, 0.3),       # тёмно-жёлтое сияние Рыцаря (щит, ярость)
	"arcane": Color(0.55, 0.5, 1.0),     # Маг — сине-фиолетовый
	"water": Color(0.5, 0.8, 1.0),
	"lightning": Color(0.95, 0.95, 0.62),
	"wind": Color(0.75, 0.9, 0.8),
	"bog": Color(0.4, 0.62, 0.32),
	"fire": Color(1.0, 0.58, 0.18),
	"steam": Color(0.92, 0.95, 1.0),
}

# Цвет по набору карты
const SET_TINTS: Dictionary[String, String] = {
	"s_tide": "water", "s_storm": "lightning", "s_wind": "wind", "s_bog": "bog", "s_fire": "fire",
	"m_kinetic": "arcane", "m_flow": "arcane", "m_charge": "arcane",
	"k_rage": "rage", "k_warden": "steel", "k_onslaught": "steel",
	"x_fire_tide": "steam",
}
# Смешанные наборы x_<дух1>_<дух2>: цвет по первому духу
const SPIRIT_TINTS: Dictionary[String, String] = {
	"tide": "water", "storm": "lightning", "wind": "wind", "bog": "bog", "fire": "fire",
}
const CHEST: Vector3 = Vector3(0.0, 0.85, 0.0)   # высота груди над клеткой


# Какая форма и какой цвет у карты: [форма, цвет]
static func pick(card: CardData) -> Array[String]:
	var form: String = ""
	var tint: String = ""
	if card.vfx != "":
		var parts: PackedStringArray = card.vfx.split(":")
		form = parts[0]
		if parts.size() > 1:
			tint = parts[1]
	if form == "":
		form = _auto_form(card)
	if tint == "":
		tint = _auto_tint(card)
	return [form, tint]


static func _auto_form(card: CardData) -> String:
	var knight: bool = card.owner_hero == "knight"
	match card.shape:
		CardData.Shape.SELF:
			if card.block > 0 or card.ally_block > 0 or card.taunt:
				return "guard"
			if card.bonus_moves > 0 and card.damage == 0:
				return "dash"
			return "buff"
		CardData.Shape.ALLY:
			return "guard" if card.block > 0 else "buff"
		CardData.Shape.CHARGE, CardData.Shape.LEAP:
			return "dash"
		CardData.Shape.AROUND:
			return "melee" if knight else "area"
		CardData.Shape.ARC:
			return "melee"
		CardData.Shape.FELL:
			return "bash"
		CardData.Shape.LINE:
			return "wave"
		CardData.Shape.CROSS, CardData.Shape.SQUARE, CardData.Shape.WALL:
			return "area"
	# Одна клетка
	if card.special == "chain":
		return "chain"
	if card.cast_range <= 1:
		if knight:
			return "bash" if card.push >= 2 and card.damage <= 2 else "melee"
		if card.owner_hero == "mage":
			return "staff"
	return "bolt"


static func _auto_tint(card: CardData) -> String:
	match card.element:
		CardData.Element.FIRE:
			return "fire"
		CardData.Element.WATER:
			return "water"
		CardData.Element.ICE:
			return "water"
		CardData.Element.LIGHTNING:
			return "lightning"
	if SET_TINTS.has(card.card_set):
		return SET_TINTS[card.card_set]
	if card.card_set.begins_with("x_"):
		var first: String = card.card_set.split("_")[1]
		if SPIRIT_TINTS.has(first):
			return SPIRIT_TINTS[first]
	return "arcane" if card.owner_hero == "mage" else "steel"


# Проиграть эффект карты. caster — фигурка героя, cells — клетки удара в мире (центры на земле).
# chain — сколько звеньев Цепи уже набрано: с каждым эффект чуть крупнее и ярче (до +30%).
# Ждать через await: возвращается, когда главное попадание показано (остальное доигрывает само).
static func play(vfx: VfxPlayer, card: CardData, caster: Node3D, cells: Array[Vector3], chain: int) -> void:
	var picked: Array[String] = pick(card)
	var form: String = picked[0]
	var tint: String = picked[1]
	var color: Color = TINTS.get(tint, TINTS["steel"])
	var k: float = 1.0 + 0.05 * clampi(chain, 0, 6)
	var from: Vector3 = caster.global_position
	var dir: Vector3 = Vector3.FORWARD
	if not cells.is_empty() and (cells[0] - from).length() > 0.1:
		dir = cells[0] - from
	dir.y = 0.0
	dir = dir.normalized()
	var tree: SceneTree = vfx.get_tree()

	if card.is_call:
		# Зов духа: огонёк срывается с плеча — вспышка цвета духа вокруг героя
		vfx.burst("rise", from + Vector3(0, 0.2, 0), 1.2 * k, 0, color)
		vfx.ring(from + Vector3(0, 0.05, 0), color, 2.4, 0.45, 2.5)
		vfx.light_flash(from + Vector3(0, 1.2, 0), color, 3.0, 4.0, 0.4)
		await tree.create_timer(0.15).timeout

	match form:
		"melee":
			var sweep: float = 110.0
			var radius: float = 0.95
			var time: float = 0.17
			if card.shape == CardData.Shape.AROUND:
				sweep = 360.0
				radius = 1.2
				time = 0.26
			elif card.shape == CardData.Shape.ARC:
				sweep = 160.0
				radius = 1.15
			vfx.slash(from, dir, color, radius * k, sweep, time)
			await tree.create_timer(time * 0.6).timeout
			for c in cells:
				_impact(vfx, tint, color, c, dir, 0.8 * k)
			await tree.create_timer(0.08).timeout
		"bash":
			var target: Vector3 = cells[0] if not cells.is_empty() else from + dir
			vfx.ring(target + Vector3(0, 0.05, 0), color, 1.8 * k, 0.3, 2.2)
			vfx.burst("dust", target + Vector3(0, 0.2, 0), 1.2 * k)
			vfx.burst("speed_lines", target + CHEST, k, 0, color, dir)
			_impact(vfx, tint, color, target, dir, 0.8 * k)
			await tree.create_timer(0.18).timeout
		"staff":
			vfx.slash(from, dir, color, 0.8 * k, 100.0, 0.14, 0.95, 0.22)
			await tree.create_timer(0.09).timeout
			for c in cells:
				vfx.burst("glints", c + CHEST, k, 0, color)
				vfx.burst("impact", c + CHEST, k, 1, color)
			await tree.create_timer(0.1).timeout
		"dash":
			vfx.burst("dust", from + Vector3(0, 0.2, 0), 1.4 * k)
			vfx.burst("speed_lines", from + Vector3(0, 0.7, 0), 1.2 * k, 0, color, -dir)
			if card.shape == CardData.Shape.LEAP:
				# Приземление: широкое кольцо, вспышка, пыль
				vfx.ring(from + Vector3(0, 0.05, 0), color, 3.0 * k, 0.4, 2.5)
				vfx.light_flash(from + Vector3(0, 0.6, 0), color, 2.5, 4.0, 0.25)
			else:
				vfx.ring(from + Vector3(0, 0.05, 0), color, 1.5, 0.3, 1.6)
			for c in cells:
				_impact(vfx, tint, color, c, dir, 0.9 * k)
			await tree.create_timer(0.18).timeout
		"guard":
			var shield_color: Color = TINTS["rage"] if tint == "steel" or tint == "rage" else color
			var targets: Array[Vector3] = cells.duplicate() if not cells.is_empty() else _one(from)
			for t in targets:
				vfx.dome(t, shield_color, 0.8 * k)
				vfx.ring(t + Vector3(0, 0.05, 0), shield_color, 1.6, 0.35, 1.8)
				vfx.burst("rise", t + Vector3(0, 0.1, 0), 0.6, 0, shield_color)
			await tree.create_timer(0.25).timeout
		"buff":
			var targets: Array[Vector3] = cells.duplicate() if not cells.is_empty() and card.shape == CardData.Shape.ALLY else _one(from)
			for t in targets:
				vfx.burst("rise", t + Vector3(0, 0.1, 0), k, 0, color)
				vfx.ring(t + Vector3(0, 0.05, 0), color, 1.5 * k, 0.35, 2.0)
				vfx.light_flash(t + Vector3(0, 1.0, 0), color, 1.5, 3.0, 0.3)
				if tint == "arcane":
					vfx.burst("glints", t + Vector3(0, 1.2, 0), k, 0, color)
			await tree.create_timer(0.25).timeout
		"bolt":
			if cells.is_empty():
				return
			if tint == "lightning":
				for c in cells:
					_sky_strike(vfx, c, color, k)
					await tree.create_timer(0.05).timeout
				await tree.create_timer(0.12).timeout
			else:
				var start: Vector3 = from + Vector3(0, 1.15, 0) + dir * 0.35
				var dist: float = start.distance_to(cells[0] + CHEST)
				var size: float = 0.6 if tint == "fire" else 0.45
				await vfx.projectile(start, cells[0] + CHEST, color, size * k, 0.14 + dist * 0.025, 0.25)
				for c in cells:
					_impact(vfx, tint, color, c, dir, k)
		"chain":
			if cells.is_empty():
				return
			_sky_strike(vfx, cells[0], color, k)
			await tree.create_timer(0.08).timeout
			for i in range(1, cells.size()):
				vfx.lightning(cells[i - 1] + CHEST, cells[i] + CHEST, color, 0.05)
				vfx.burst("shock", cells[i] + CHEST, k, 0, color)
				vfx.light_flash(cells[i] + CHEST, color, 1.5, 2.5, 0.15)
				await tree.create_timer(0.07).timeout
		"wave":
			var ordered: Array[Vector3] = cells.duplicate()
			ordered.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(from) < b.distance_to(from))
			if tint == "lightning" and not ordered.is_empty():
				vfx.lightning(from + Vector3(0, 1.1, 0), ordered[-1] + CHEST, color, 0.07, 14)
				vfx.light_flash(from + Vector3(0, 1.0, 0), color, 2.0, 4.0, 0.2)
			for c in ordered:
				_impact(vfx, tint, color, c, dir, 0.8 * k, true)
				await tree.create_timer(0.035).timeout
			await tree.create_timer(0.1).timeout
		"area":
			if cells.is_empty():
				cells = _one(from)
			var center: Vector3 = Vector3.ZERO
			for c in cells:
				center += c
			center /= cells.size()
			var far: bool = center.distance_to(from) > 1.5
			if card.special == "meteor":
				# Метеор: падает с неба наискосок
				await vfx.projectile(center + Vector3(2.0, 8.0, 1.0), center + Vector3(0, 0.3, 0), color, 1.0 * k, 0.32, 0.0)
				vfx.ring(center + Vector3(0, 0.05, 0), color, 4.0, 0.5, 3.0)
				vfx.light_flash(center + Vector3(0, 1.0, 0), color, 4.0, 6.0, 0.35)
			elif tint == "lightning":
				for i in mini(cells.size(), 4):
					_sky_strike(vfx, cells[i], color, k)
					await tree.create_timer(0.04).timeout
			elif far and (tint == "fire" or tint == "arcane" or tint == "steam"):
				# Снаряд по дуге в центр области
				await vfx.projectile(from + Vector3(0, 1.15, 0) + dir * 0.35, center + CHEST, color, 0.6 * k, 0.28, 1.2)
			vfx.ring(center + Vector3(0, 0.05, 0), color, (2.6 if cells.size() > 3 else 1.8) * k, 0.4, 2.2)
			for c in cells:
				_impact(vfx, tint, color, c, (c - from).normalized() if c.distance_to(from) > 0.1 else dir, 0.85 * k, true)
			await tree.create_timer(0.15).timeout
		_:
			await tree.create_timer(0.2).timeout


static func _one(v: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [v]
	return out


# Разряд с неба в клетку: молния, вспышка света, искры, кольцо
static func _sky_strike(vfx: VfxPlayer, at: Vector3, color: Color, k: float) -> void:
	var top: Vector3 = at + Vector3(randf_range(-0.6, 0.6), 6.0, randf_range(-0.6, 0.6))
	vfx.lightning(top, at + Vector3(0, 0.1, 0), color, 0.08 * k, 12)
	vfx.light_flash(at + Vector3(0, 1.2, 0), color, 3.0, 4.0, 0.2)
	vfx.burst("shock", at + Vector3(0, 0.3, 0), 1.2 * k, 0, color)
	vfx.ring(at + Vector3(0, 0.05, 0), color, 1.4, 0.25, 2.5)


# Попадание карты по клетке — по цвету (стихии). Урон и искры по материалу врага
# показывает сам урон (VfxPlayer.hit), здесь — только «чем ударили».
# area — для волн и областей: на каждой клетке, поэтому скромнее и с кольцом.
static func _impact(vfx: VfxPlayer, tint: String, color: Color, at: Vector3, dir: Vector3, k: float,
		area: bool = false) -> void:
	var chest: Vector3 = at + CHEST
	match tint:
		"water":
			vfx.burst("splash_up", at + Vector3(0, 0.1, 0), k)
			vfx.ring(at + Vector3(0, 0.05, 0), color, 1.3, 0.45, 1.4)
		"lightning":
			vfx.burst("shock", chest, k, 0, color)
			if not area:
				vfx.light_flash(chest, color, 2.0, 3.0, 0.15)
		"wind":
			vfx.burst("gust", chest, k, 0, color, dir)
			vfx.burst("leaves", chest, 0.7 * k, 0, Color(0, 0, 0, 0), dir)
		"bog":
			vfx.burst("mud", at + Vector3(0, 0.1, 0), k)
			vfx.burst("bubbles", at + Vector3(0, 0.1, 0), k)
			vfx.ring(at + Vector3(0, 0.05, 0), color, 1.2, 0.5, 1.0)
		"fire":
			vfx.burst("fire_puff", at + Vector3(0, 0.3, 0), k)
			vfx.burst("embers", chest, k)
			vfx.burst("smoke", at + Vector3(0, 0.6, 0), 0.6 * k)
			if not area:
				vfx.light_flash(chest, color, 2.5, 3.5, 0.25)
		"steam":
			vfx.burst("steam_puff", at + Vector3(0, 0.3, 0), k)
		"arcane":
			vfx.burst("impact", chest, k, 1, color)
			vfx.burst("glints", chest, k, 0, color)
			if area:
				vfx.ring(at + Vector3(0, 0.05, 0), color, 1.2, 0.3, 1.8)
		_:   # steel, rage — оружие: искры цвета стали/ярости
			vfx.burst("sparks", chest, k, 0, color * 1.2)

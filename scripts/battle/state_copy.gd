class_name StateCopy
extends RefCounted
# Снимок полей объекта и возврат к нему — основа отмены хода и копий боя.
#
# Берёт ВСЕ переменные скрипта по списку свойств, а не перечень руками:
# новое поле, добавленное в BattleLogic или BattleUnit, попадёт в снимок само.
# Массивы и словари копируются (вложенные — тоже), а ресурсы (CardData, EnemyData)
# и юниты остаются теми же объектами — их не меняют на месте (юниты снимаются отдельно).

static var _names_cache: Dictionary = {}   # скрипт -> список имён его переменных


# Имена переменных скрипта объекта (без встроенных свойств Godot)
# (StringName — get/set по ним быстрее, чем по строкам)
static func names_of(obj: Object) -> Array[StringName]:
	var script: Script = obj.get_script()
	if _names_cache.has(script):
		return _names_cache[script]
	var names: Array[StringName] = []
	for p: Dictionary in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(StringName(p["name"]))
	_names_cache[script] = names
	return names


# Скопировать все поля из одного объекта в другой (того же скрипта) без промежуточного снимка
static func copy_fields(from: Object, to: Object) -> void:
	for n: StringName in names_of(from):
		var v: Variant = from.get(n)
		var t: int = typeof(v)
		if t == TYPE_ARRAY or t == TYPE_DICTIONARY:
			v = dup(v)
		to.set(n, v)


# Снимок: имя переменной -> копия значения. skip — какие поля не брать.
static func capture(obj: Object, skip: Array[String] = []) -> Dictionary:
	var state: Dictionary = {}
	for n: StringName in names_of(obj):
		if not skip.has(n):
			state[n] = dup(obj.get(n))
	return state


# Вернуть поля объекта к снимку. Снимок копируется ещё раз — его можно применять много раз.
# Ключи, начинающиеся с «__», — служебные (их разбирает тот, кто делал снимок).
static func apply(obj: Object, state: Dictionary) -> void:
	for n: String in state:
		if not n.begins_with("__"):
			obj.set(n, dup(state[n]))


# Копия значения: массивы и словари — новые (вложенные тоже), остальное — как есть.
# Типизированные (Array[int], Dictionary[Vector2i, int], Array[CardData]) внутри себя
# других массивов не держат — им хватает быстрой мелкой копии.
static func dup(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var arr: Array = v
			return arr.duplicate(not arr.is_typed())
		TYPE_DICTIONARY:
			var d: Dictionary = v
			return d.duplicate(not (d.is_typed_key() and d.is_typed_value()))
	return v


# Копия значения, где юниты заменены по словарю map (юнит боя -> его копия):
# и в элементах массивов, и в ключах и значениях словарей. Нужно копии боя,
# чтобы её словари вроде «герой -> сколько сбросов осталось» указывали на её же героев.
# Контейнеры, в которых юнитов быть не может (Array[int], Dictionary[Vector2i, int]),
# просто копируются — так быстрее (копия боя делается сотни раз за ход врагов).
static func remap_refs(v: Variant, map: Dictionary) -> Variant:
	if v is Object:
		return map.get(v, v)
	if v is Array:
		var arr: Array = v
		if arr.is_typed() and not _may_hold_unit(arr.get_typed_builtin(), arr.get_typed_script()):
			return arr.duplicate()
		var out_arr: Array = arr.duplicate()   # сохраняет тип массива (Array[BattleUnit])
		for i in out_arr.size():
			out_arr[i] = remap_refs(out_arr[i], map)
		return out_arr
	if v is Dictionary:
		var src: Dictionary = v
		if src.is_typed_key() and src.is_typed_value() \
				and not _may_hold_unit(src.get_typed_key_builtin(), src.get_typed_key_script()) \
				and not _may_hold_unit(src.get_typed_value_builtin(), src.get_typed_value_script()):
			return src.duplicate()
		var out: Dictionary = src.duplicate()
		out.clear()
		for k: Variant in src:
			out[remap_refs(k, map)] = remap_refs(src[k], map)
		return out
	return v


# Может ли в элементе такого типа оказаться юнит (BattleUnit или любой объект без уточнения)
static func _may_hold_unit(builtin: int, script: Variant) -> bool:
	if builtin != TYPE_OBJECT:
		return false
	return script == null or script == BattleUnit


# Чем два снимка отличаются: список имён полей (для тестов и отладки)
static func diff(a: Dictionary, b: Dictionary, prefix: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in a:
		var name: String = prefix + _key_name(k)
		if not b.has(k):
			out.append(name + " (нет во втором)")
		elif a[k] is Dictionary and b[k] is Dictionary and (k is Object or str(k).begins_with("__") or prefix.begins_with("__units")):
			out.append_array(diff(a[k], b[k], name + "."))   # снимок юнита или служебный раздел — по полям
		elif typeof(a[k]) != typeof(b[k]) or a[k] != b[k]:
			out.append(name)
	for k: Variant in b:
		if not a.has(k):
			out.append(prefix + _key_name(k) + " (нет в первом)")
	return out


static func _key_name(k: Variant) -> String:
	if k is Object and "title" in k:
		return "%s#%d" % [k.get("title"), k.get("id")]
	return str(k)


# Снимок, где юниты заменены строками «unit#id»: так два снимка можно сравнить,
# даже если враг, призванный в ход врагов, в каждом из них — свой объект.
static func by_ids(v: Variant) -> Variant:
	if v is Object and v.get_script() != null and "is_hero" in v:
		return "unit#%d" % v.get("id")
	if v is Array:
		var arr: Array = []
		for x: Variant in v:
			arr.append(by_ids(x))
		return arr
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in v:
			out[by_ids(k)] = by_ids(v[k])
		return out
	return v

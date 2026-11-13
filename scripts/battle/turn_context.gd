class_name TurnContext
extends RefCounted
# Контекст хода игрока: что уже сделали герои в этот ход. По нему работают
# условия карт («если прошёл 2 клетки», «если уже сыграно 2 атаки») и
# пассивки врагов. Сбрасывается в начале каждого хода героев.
# Герой в словарях — по id его HeroData ("mage", "knight").

enum Action { NONE, MOVE, ATTACK, SPELL, SCRAP }

var hex_moved: Dictionary = {}           # герой -> сколько клеток прошёл за ход
var straight_moved: Dictionary = {}      # герой -> сколько клеток прошёл подряд по одной оси
var _straight_dir: Dictionary = {}       # герой -> по какой оси идёт сейчас
var cards_played: Dictionary = {}        # герой -> сколько карт сыграл (сброс «в ноги» не считается)
var attack_cards: Dictionary = {}        # герой -> сколько карт «Атака» сыграл
var spells_played: int = 0               # сколько «Заклинаний» сыграл отряд
var last_action: Action = Action.NONE    # что отряд сделал последним
var last_card_owner: String = ""         # чья карта сыграна последней (для «резонанса» героев)
var rot_storm: bool = false              # «Гнилая гроза»: молния по опутанным вдвое
var chain: int = 0                       # Цепь: сколько карт отряд сыграл за ход (общая на двоих)
var spells_this_turn: int = 0            # сколько Заклинаний сыграно в этот ход (для шамана)
var last_mage_card: CardData = null      # последняя карта мага в этот ход (для «Эха»)


func reset() -> void:
	hex_moved.clear()
	straight_moved.clear()
	_straight_dir.clear()
	cards_played.clear()
	attack_cards.clear()
	spells_played = 0
	last_action = Action.NONE
	last_card_owner = ""
	chain = 0
	rot_storm = false
	spells_this_turn = 0
	last_mage_card = null


# Герой прошёл по клеткам path (первая клетка — где он стоял). Шаг в другую сторону
# обрывает «прямую»: считается заново с одной клетки.
func note_move(hero: String, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var step: Vector2i = path[i] - path[i - 1]
		hex_moved[hero] = moved(hero) + 1
		if step == _straight_dir.get(hero, Vector2i.ZERO):
			straight_moved[hero] = straight(hero) + 1
		else:
			straight_moved[hero] = 1
			_straight_dir[hero] = step
	if path.size() > 1:
		last_action = Action.MOVE


# Герой сыграл карту основным способом. Сыгранная карта «гасит» его разгон.
func note_card(hero: String, is_attack: bool, is_spell: bool) -> void:
	cards_played[hero] = played(hero) + 1
	chain += 1
	if is_attack:
		attack_cards[hero] = attacks(hero) + 1
		last_action = Action.ATTACK
	if is_spell:
		spells_played += 1
		last_action = Action.SPELL
	if not is_attack and not is_spell:
		last_action = Action.SPELL if last_action == Action.NONE else last_action
	last_card_owner = hero
	straight_moved[hero] = 0
	_straight_dir[hero] = Vector2i.ZERO


# Карта сброшена «в ноги»: врагам это не видно, разгон сохраняется
func note_scrap(hero: String) -> void:
	last_action = Action.SCRAP
	last_card_owner = hero


# Добавить герою «разгона» без шагов (например, его толкнул маг картой)
func add_straight(hero: String, tiles: int) -> void:
	straight_moved[hero] = straight(hero) + tiles


func moved(hero: String) -> int:
	return hex_moved.get(hero, 0)


func straight(hero: String) -> int:
	return straight_moved.get(hero, 0)


func played(hero: String) -> int:
	return cards_played.get(hero, 0)


func attacks(hero: String) -> int:
	return attack_cards.get(hero, 0)


# Копия контекста — для прогноза и превью на копии боя
func copy() -> TurnContext:
	var c := TurnContext.new()
	c.hex_moved = hex_moved.duplicate()
	c.straight_moved = straight_moved.duplicate()
	c._straight_dir = _straight_dir.duplicate()
	c.cards_played = cards_played.duplicate()
	c.attack_cards = attack_cards.duplicate()
	c.spells_played = spells_played
	c.last_action = last_action
	c.last_card_owner = last_card_owner
	c.chain = chain
	c.rot_storm = rot_storm
	c.spells_this_turn = spells_this_turn
	c.last_mage_card = last_mage_card
	return c

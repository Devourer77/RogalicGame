extends Control
# Привал: оба героя восстанавливают часть здоровья.


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	var fire: TextureRect = UiKit.icon_rect("rest", 84, Color(1.0, 0.68, 0.32))
	fire.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(fire)
	column.add_child(UiKit.make_title("Привал", 40, UiKit.BRASS.lightened(0.25)))
	column.add_child(UiKit.make_text("Сухая кочка, огонь и час тишины. Топь подождёт.", 18, UiKit.TEXT_DIM))
	column.add_child(UiKit.party_bar())
	var heal_share: float = Run.rest_percent()
	var percent: int = roundi(heal_share * 100.0)
	var gains: PackedStringArray = []
	for rh in Run.party:
		var amount: int = mini(ceili(rh.data.max_hp * heal_share), rh.data.max_hp - rh.hp)
		gains.append("%s +%d" % [rh.data.title, amount])
	var rest: Button = UiKit.make_button("Отдохнуть  ·  +%d%% здоровья" % percent, _rest, "heart", true)
	rest.custom_minimum_size.x = 340
	rest.tooltip_text = "Вылечит: " + ", ".join(gains)
	column.add_child(rest)
	var skip: Button = UiKit.make_button("Идти дальше", Run.goto.bind(Run.MAP_SCENE))
	skip.custom_minimum_size.x = 340
	column.add_child(skip)


func _rest() -> void:
	var heal_share: float = Run.rest_percent()
	Run.rest_used = true   # «Чистый бинт» действует только на первый привал
	for rh in Run.party:
		Run.heal_hero(rh, ceili(rh.data.max_hp * heal_share))
	Run.goto(Run.MAP_SCENE)

extends Control
# Привал: оба героя восстанавливают часть здоровья.


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_child(UiKit.make_label("Привал", 40))
	column.add_child(UiKit.make_label("Тихая поляна у костра.", 20))
	column.add_child(UiKit.make_label(UiKit.run_status(), 16))
	var percent: int = roundi(Run.REST_HEAL_PERCENT * 100.0)
	column.add_child(UiKit.make_button("Отдохнуть (+%d%% HP каждому)" % percent, _rest))
	column.add_child(UiKit.make_button("Идти дальше", Run.goto.bind(Run.MAP_SCENE)))


func _rest() -> void:
	for rh in Run.party:
		rh.heal(ceili(rh.data.max_hp * Run.REST_HEAL_PERCENT))
	Run.goto(Run.MAP_SCENE)

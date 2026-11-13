extends Control
# Трофей за босса: три закрытых оберега, берёшь один — он открывается навсегда.
# Отказаться нельзя: это подарок. Потом — экран итога забега.

var _take_button: Button
var _selected: RelicData = null
var _frames: Dictionary[RelicData, PanelContainer] = {}


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 14)
	column.add_child(UiKit.make_title("Трофей", 44, UiKit.BRASS.lightened(0.25)))
	column.add_child(UiKit.make_text("Среди добычи — вещи Стражи. Одну можно унести: она откроется на Полке трофеев навсегда.", 17, UiKit.TEXT_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for charm in Run.trophy_choices:
		row.add_child(_make_card(charm))
	_take_button = UiKit.make_button("Взять", _take, "", true)
	_take_button.disabled = true
	column.add_child(_take_button)


func _make_card(charm: RelicData) -> Control:
	var frame: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.85), UiKit.LINE, 2)
	frame.custom_minimum_size = Vector2(230, 0)
	_frames[charm] = frame
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)
	var icon: TextureRect = UiKit.icon_rect(charm.icon if UiKit.has_icon(charm.icon) else "star", 48, UiKit.BRASS.lightened(0.2))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(UiKit.make_title(charm.title, 22, UiKit.TEXT))
	box.add_child(UiKit.make_text(charm.desc, 15, UiKit.TEXT_DIM, 200))
	var pick: Button = UiKit.make_button("Выбрать", _select.bind(charm))
	pick.custom_minimum_size.x = 160
	box.add_child(pick)
	return frame


func _select(charm: RelicData) -> void:
	_selected = charm
	for c: RelicData in _frames:
		var border: Color = UiKit.BRASS.lightened(0.25) if c == charm else UiKit.LINE
		_frames[c].add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.85), border, 3 if c == charm else 2, 9, 12, 10))
	_take_button.disabled = false


func _take() -> void:
	if _selected == null:
		return
	Sfx.play("coin", 0.05)
	Meta.unlock_charm(_selected.id)   # сохраняется сразу
	Run.game_over(true)

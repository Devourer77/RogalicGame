extends Control
# Карта забега: ряды точек снизу вверх, наверху босс.
# Можно пойти только в точки, куда ведёт дорожка из текущей.

const COL_SPACING: float = 170.0
const ROW_SPACING: float = 70.0
const NODE_SIZE := Vector2(120, 40)

var _area: Control                          # область, где рисуются точки и дорожки
var _buttons: Dictionary[MapNode, Button] = {}


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_child(UiKit.make_label("Карта забега", 32))

	var status: Label = UiKit.make_label(UiKit.run_status() + "     Сид: %d" % Run.seed_value, 18)
	var decks: PackedStringArray = []
	for rh in Run.party:
		decks.append("%s:\n%s" % [rh.data.title, Run.deck_summary(rh)])
	status.tooltip_text = "\n\n".join(decks)   # наведи на строку — увидишь колоды
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(status)

	_area = Control.new()
	_area.custom_minimum_size = Vector2(COL_SPACING * (Run.MAP_COLS - 1) + NODE_SIZE.x,
			ROW_SPACING * (Run.MAP_ROWS - 1) + NODE_SIZE.y)
	_area.draw.connect(_draw_links)   # дорожки рисуем сами в сигнале draw
	column.add_child(_area)

	var available: Array[MapNode] = Run.available_nodes()
	for n in Run.map:
		var b := Button.new()
		b.text = n.type_name()
		b.size = NODE_SIZE
		b.position = _node_position(n)
		b.disabled = not available.has(n)
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, n, available.has(n))
		b.pressed.connect(Run.enter_node.bind(n))
		_area.add_child(b)
		_buttons[n] = b

	column.add_child(UiKit.make_label("Бой — враги и награда картой. Элита — бой с сильным врагом. Событие — выбор с риском.\nЛавка — купить или убрать карту. Привал — лечение.", 16))


# Цвет кнопки по типу точки; куда можно пойти — яркая рамка, остальное приглушено
func _style_button(b: Button, n: MapNode, is_available: bool) -> void:
	var colors: Dictionary = {
		MapNode.Type.BATTLE: Color(0.45, 0.2, 0.2),
		MapNode.Type.EVENT: Color(0.25, 0.25, 0.5),
		MapNode.Type.SHOP: Color(0.45, 0.38, 0.15),
		MapNode.Type.REST: Color(0.2, 0.42, 0.25),
		MapNode.Type.BOSS: Color(0.6, 0.1, 0.1),
		MapNode.Type.ELITE: Color(0.5, 0.27, 0.12),
	}
	var box := StyleBoxFlat.new()
	box.bg_color = colors[n.type]
	box.set_corner_radius_all(6)
	if is_available:
		box.set_border_width_all(3)
		box.border_color = Color(1.0, 0.9, 0.4)
	elif n == Run.current:
		box.set_border_width_all(3)
		box.border_color = Color(0.5, 1.0, 0.5)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85))
	if not is_available and not n.visited and n != Run.current:
		b.modulate = Color(1, 1, 1, 0.55)


# Левый верхний угол кнопки точки. Ряд 0 — внизу.
func _node_position(n: MapNode) -> Vector2:
	var cols: int = Run.row_nodes(n.row).size()
	var x_offset: float = (Run.MAP_COLS - cols) * COL_SPACING / 2.0   # одиночного босса — по центру
	var x: float = x_offset + n.col * COL_SPACING
	var y: float = (Run.MAP_ROWS - 1 - n.row) * ROW_SPACING
	return Vector2(x, y)


func _draw_links() -> void:
	for n in Run.map:
		for c in n.next:
			var target: MapNode = Run.find_map_node(n.row + 1, c)
			if target == null:
				continue
			var from: Vector2 = _node_position(n) + NODE_SIZE / 2.0
			var to: Vector2 = _node_position(target) + NODE_SIZE / 2.0
			var color := Color(0.5, 0.5, 0.55)
			if n.visited and target.visited:
				color = Color(0.5, 1.0, 0.5)
			_area.draw_line(from, to, color, 3.0)

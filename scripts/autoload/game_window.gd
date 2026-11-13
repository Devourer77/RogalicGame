extends Node
# Окно игры: по умолчанию полный экран (разрешение монитора, не меньше Full HD на обычном мониторе).
# F11 или Alt+Enter — переключить полный экран / окно 1920×1080.
# Интерфейс свёрстан под 1280×720 и растягивается под любое окно (stretch = canvas_items):
# текст и 3D всё равно рисуются в настоящем разрешении экрана, поэтому картинка чёткая.

const WINDOW_SIZE: Vector2i = Vector2i(1920, 1080)   # размер окна в оконном режиме


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Окно не больше рабочей области монитора (на мониторе 1920×1080 мешает панель задач)
		var area: Rect2i = DisplayServer.screen_get_usable_rect()
		var size: Vector2i = WINDOW_SIZE.min(area.size)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

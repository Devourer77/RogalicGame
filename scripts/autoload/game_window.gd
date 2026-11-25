extends Node
# Окно игры: по умолчанию полный экран (разрешение монитора, не меньше Full HD на обычном мониторе).
# F11 или Alt+Enter — переключить полный экран / окно 1920×1080.
# Базовое разрешение — 1920×1080 (project.godot), интерфейс растягивается под любое окно
# (stretch = canvas_items) с множителем Settings.BASE_UI_SCALE; текст и 3D рисуются
# в настоящем разрешении экрана, поэтому картинка чёткая.

const WINDOW_SIZE: Vector2i = Vector2i(1920, 1080)   # размер окна в оконном режиме


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


# Переключение запоминается в настройках (Settings.fullscreen), окно меняет Settings.apply_window()
func toggle_fullscreen() -> void:
	Settings.set_value("fullscreen", not Settings.fullscreen)

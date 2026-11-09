# Rogalic

Пошаговый карточный рогалик в фэнтези-сеттинге: тактика на сетке, заклинания тянутся из колоды. 3D, PC.

**Движок:** Godot 4.7 (GDScript) · **Модели:** Blender 5.2 → glTF (`.glb`)

## Как запустить
1. Установить [Godot 4.7](https://godotengine.org/download).
2. В менеджере проектов Godot нажать **Import** и выбрать `project.godot` из этой папки.
3. Открыть `scenes/battle.tscn` и нажать **F6**.

## Что уже есть
- Поле 8×8 из каменных плит (4 варианта текстур, случайная раскладка по сиду).
- Герой-маг (low-poly модель из Blender), ходит по клику мыши.

## Структура
- `scenes/` — сцены Godot
- `scripts/` — код (GDScript)
- `assets/models/` — модели `.glb`, исходники Blender — в `assets/models/src/`
- `assets/textures/` — текстуры
- `CLAUDE.md` — правила разработки проекта

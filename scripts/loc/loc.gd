class_name Loc
extends RefCounted
# Перевод текста. Все строки, которые видит игрок, проходят через Loc.t("…"):
# пока перевода нет (язык «ru»), возвращается та же строка.
# Строки собирает в каталог tools/i18n/extract_strings.py → locale/messages.pot;
# переводы — файлы locale/<язык>.po (en.po, zh_CN.po…), их подключает Settings.apply_language().
# Почему не tr(): tr() нет в статических функциях, а Loc.t работает везде.


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))

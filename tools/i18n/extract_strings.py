# Собирает все тексты игры для перевода в locale/messages.pot (формат gettext).
# Запуск из папки проекта:  python tools/i18n/extract_strings.py
#
# Откуда берутся строки:
#  - .gd: все строковые литералы с русскими буквами (и в Loc.t, и в константах);
#  - .tres: все строки ресурсов с русскими буквами (поля и списки).
# Переводчик открывает messages.pot в Poedit (или любом редакторе .po), сохраняет как
# locale/en.po, locale/zh_CN.po — и язык появляется в настройках сам.
import glob
import os
import re

CYR = re.compile("[А-Яа-яЁё]")
LIT = re.compile(r'(?<![&^])"((?:[^"\\\n]|\\.)*)"')
TRES_FIELD = re.compile(r'^(\w+) = "((?:[^"\\]|\\.)*)"\s*$')


def gd_files():
	return [f for f in glob.glob("**/*.gd", recursive=True)
		if not f.startswith(("tests/", "tools/", ".godot/", "addons/")) and "/src/" not in f]


def collect():
	found = {}   # строка → список мест «файл:строка»
	for f in sorted(gd_files()):
		with open(f, encoding="utf-8") as fh:
			for no, line in enumerate(fh, 1):
				code = line.lstrip()
				if code.startswith("#") or code.startswith(("print(", "push_error(", "push_warning(")):
					continue
				for m in LIT.finditer(line):
					s = m.group(1)
					if CYR.search(s):
						found.setdefault(s, []).append("%s:%d" % (f, no))
	for f in sorted(glob.glob("resources/**/*.tres", recursive=True)):
		with open(f, encoding="utf-8") as fh:
			for no, line in enumerate(fh, 1):
				# любые строки с русскими буквами: поля, списки (branch_titles = Array[String]([…]))
				for m in LIT.finditer(line):
					if CYR.search(m.group(1)):
						found.setdefault(m.group(1), []).append("%s:%d" % (f, no))
	return found


def po_escape(s):
	# Строки уже в виде GDScript-литерала: \\n, \\" и т. п. совпадают с экранированием .po
	return s


def main():
	found = collect()
	os.makedirs("locale", exist_ok=True)
	with open("locale/messages.pot", "w", encoding="utf-8", newline="\n") as out:
		out.write('# Тексты игры для перевода. Собрано tools/i18n/extract_strings.py — руками не править.\n')
		out.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Language: ru\\n"\n\n')
		for s in sorted(found, key=lambda k: found[k][0]):
			places = found[s]
			out.write("#: %s\n" % " ".join(places[:5]))
			out.write('msgid "%s"\nmsgstr ""\n\n' % po_escape(s))
	words = sum(len(s.split()) for s in found)
	print("строк: %d, слов: %d → locale/messages.pot" % (len(found), words))


if __name__ == "__main__":
	main()

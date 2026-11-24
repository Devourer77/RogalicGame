# Оборачивает русские строки в .gd в Loc.t("…"), чтобы их можно было перевести.
# Запуск из папки проекта:  python tools/i18n/wrap_strings.py [файлы...]
# Без аргументов — все .gd, кроме tests/, tools/ и исходников моделей.
#
# Что НЕ оборачивается (там вызов функции нельзя или не нужен):
#  - const, enum, static var и всё внутри их скобок; аннотации (@export…);
#  - заголовки func (значения по умолчанию);
#  - образцы match ("текст":);
#  - print / push_error / push_warning / assert (отладка);
#  - уже обёрнутое (Loc.t, tr), &"…" и ^"…", многострочные """…""", комментарии.
# Такие строки всё равно попадают в каталог (extract_strings.py), а переводить их
# нужно в месте показа: Loc.t(КОНСТАНТА).
import glob
import re
import sys

CYR = re.compile("[А-Яа-яЁё]")
SKIP_CALLS = ("print(", "push_error(", "push_warning(", "assert(", "printerr(")


def string_spans(line):
	"""Строковые литералы "…" в строке кода (без комментария): [(начало, конец)]"""
	spans = []
	i = 0
	n = len(line)
	while i < n:
		ch = line[i]
		if ch == "#":
			break
		if ch == '"':
			if line.startswith('"""', i):
				return None   # многострочная строка — строку целиком не трогаем
			j = i + 1
			while j < n and line[j] != '"':
				j += 2 if line[j] == "\\" else 1
			spans.append((i, j + 1))
			i = j + 1
			continue
		if ch == "'":
			j = i + 1
			while j < n and line[j] != "'":
				j += 2 if line[j] == "\\" else 1
			i = j + 1
			continue
		i += 1
	return spans


def bracket_delta(line):
	d = 0
	in_str = False
	q = ""
	i = 0
	while i < len(line):
		ch = line[i]
		if in_str:
			if ch == "\\":
				i += 2
				continue
			if ch == q:
				in_str = False
		else:
			if ch == "#":
				break
			if ch in "\"'":
				in_str, q = True, ch
			elif ch in "([{":
				d += 1
			elif ch in ")]}":
				d -= 1
		i += 1
	return d


def process(text):
	out = []
	depth_skip = 0          # >0 — внутри const/enum/static var со скобками
	in_triple = False
	changed = 0
	for line in text.split("\n"):
		stripped = line.strip()
		if in_triple:
			if stripped.count('"""') % 2 == 1:
				in_triple = False
			out.append(line)
			continue
		if stripped.count('"""') % 2 == 1:
			in_triple = True
			out.append(line)
			continue
		if depth_skip > 0:
			depth_skip += bracket_delta(line)
			out.append(line)
			continue
		if re.match(r"^(const |enum |static var |@)", stripped):
			depth_skip = max(0, bracket_delta(line))
			out.append(line)
			continue
		if re.match(r"^(static )?func ", stripped) or stripped.startswith(SKIP_CALLS) \
				or any(c in stripped for c in SKIP_CALLS):
			out.append(line)
			continue
		# образец match: "текст": или "a", "b":
		if re.match(r'^("(?:[^"\\]|\\.)*"\s*,\s*)*"(?:[^"\\]|\\.)*"\s*:\s*(#.*)?$', stripped) and not stripped.endswith(","):
			out.append(line)
			continue
		spans = string_spans(line)
		if not spans:
			out.append(line)
			continue
		new = line
		for a, b in reversed(spans):
			lit = line[a:b]
			if not CYR.search(lit):
				continue
			before = line[:a].rstrip()
			if before.endswith(("Loc.t(", "tr(", "atr(")) or line[a - 1:a] in ("&", "^"):
				continue
			new = new[:a] + "Loc.t(" + lit + ")" + new[b:]
			changed += 1
		out.append(new)
	return "\n".join(out), changed


def main():
	files = sys.argv[1:] or [f for f in glob.glob("**/*.gd", recursive=True)
		if not f.startswith(("tests/", "tools/", ".godot/", "addons/")) and "/src/" not in f
		and not f.endswith("loc/loc.gd")]
	total = 0
	for f in files:
		with open(f, encoding="utf-8", newline="") as fh:
			text = fh.read()
		new, n = process(text)
		if n:
			with open(f, "w", encoding="utf-8", newline="") as fh:
				fh.write(new)
			print("%4d  %s" % (n, f))
			total += n
	print("обёрнуто строк:", total)


if __name__ == "__main__":
	main()

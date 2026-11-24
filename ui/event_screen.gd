extends Control
# Случайное событие: текст и несколько вариантов выбора.
#
# Большинство вариантов описаны данными — списком шагов «effects», которые разбирает общий код ниже
# (_apply_step). Так новое событие — это только текст и числа, без своего кода. Шаги:
#   {"hp": -7, "who": "knight"}      — HP герою: knight / mage / all (каждому) / random (случайному)
#   {"gold": -20}                    — золото (выбор нельзя нажать, если золота не хватает)
#   {"card": "mage", "rare": true}   — карта герою из его наград (базовый пул + карты духов);
#                                      rare — редкая ★, иначе обычная
#   {"remove": "mage"}               — игрок сам убирает 1 карту из колоды героя (как в лавке)
#   {"echoes": 6}                    — Отзвуки (получишь в хабе после забега)
#   {"relic": 1}                     — случайная реликвия (нельзя, если места кончились)
#   {"relic_pick": 3}                — реликвия на выбор из трёх, как за элиту (тз-события.md)
#   {"fight": "elite"} / {"fight": "<id отряда>"} — бой прямо из события (элита — вторая элита забега,
#                                      с реликвией в награду); шаг — последний, итог покажет экран награды
#   {"fog": 1}                       — туман на карте отступает на столько рядов (до конца акта)
#   {"heal_pct": 30, "who": "all"}   — лечение долей от максимума HP
#   {"upgrade": "knight"}            — улучшить случайную карту героя (ветка I или II — наугад)
#   {"wound": "mage"}                — герою «Рана» в колоду
#   {"keepers": "calm"} / {"keepers": "fewer"} — Хранители до конца акта бьют слабее / в следующем бою
#                                      с ними на одного меньше
# Условия появления события: «branch» ("bog" / "forest" — акт 1, "tract" / "deep" — акт 2), «act» (1 — только
# акт 1, 2 — акты 2 и 3; без него — любой акт), «min_row», «need» — особое условие (см. event_allowed).
# Случайный исход: «chance» (0..1), «win» и «lose» — у каждого свои effects и текст.
# «random» в одном выборе — один и тот же герой (кто потерял HP, тот и получает карту).
# Особые варианты (оберег, дух, бой в пещере) — через «action» и свой код в _special().
# Цена в HP не убивает: у героя остаётся хотя бы 1 HP (RunHero.lose_hp).

const EVENTS: Array[Dictionary] = [
	{
		"title": "Заброшенный алтарь",
		"text": "В зарослях — каменный алтарь, покрытый рунами. Руны жадно светятся, когда ты подходишь.",
		"options": [
			{"label": "Пролить кровь", "effects": [{"hp": -6, "who": "random"}, {"card": "random", "rare": true}],
					"result": "Руны гаснут, и кровь уходит в камень. Взамен в памяти всплывает чужой приём."},
			{"label": "Уйти", "result": "Руны провожают отряд тусклым светом."},
		],
	},
	{
		"title": "Лесной родник",
		"act": 1,
		"text": "Среди корней бьёт чистый родник. Над водой кружатся светлячки.",
		"options": [
			{"label": "Напиться", "effects": [{"hp": 10, "who": "all"}], "result": "Вода прохладная и придаёт сил."},
			{"label": "Бросить монету", "effects": [{"gold": -15}, {"card": "random"}],
					"result": "Монета тонет, а в голове вдруг всплывает забытый приём."},
		],
	},
	{
		"title": "Утопленный идол",
		"act": 1,
		"text": "Из трясины торчит каменный идол. На шее у него — потемневший амулет.",
		"options": [
			{"label": "Снять амулет", "effects": [{"relic": 1}], "result": "Амулет холодный и тяжелее, чем кажется."},
			{"label": "Не трогать", "result": "Идол смотрит вслед пустыми глазами."},
		],
	},
	{
		"title": "Сундук на дороге",
		"text": "Посреди тропы стоит окованный сундук. Слишком удобно, чтобы быть правдой?",
		"options": [
			{"label": "Открыть", "chance": 0.5,
					"win": {"effects": [{"gold": 40}], "result": "Внутри — золото!"},
					"lose": {"effects": [{"hp": -6, "who": "random"}], "result": "Ловушка! Иглы впиваются в руку."}},
			{"label": "Пройти мимо", "result": "Отряд обходит сундук стороной."},
		],
	},
	# Появляется, только пока в отряде нет Грозовика или Вихоря (Run.cage_spirit())
	{
		"title": "Клетка Венца",
		"id": "cage",
		"text": "У дороги — кованая клетка-фонарь с костяным венцом на крышке. Внутри мечется дух: культисты поймали его и оставили сторожить. Если разбить замок, чары клетки ударят по всем рядом.",
		"options": [
			{"label": "Отбить духа", "hint": "каждому −5 HP → дух выбирает героя", "action": "cage_free"},
			{"label": "Пройти мимо", "result": "Дух провожает отряд взглядом, пока клетка не скрывается в тумане."},
		],
	},
	# Секрет: выпадает с шансом Run.CAVE_EVENT_CHANCE, раз за забег, пока нет духа огня (см. _pick_event)
	{
		"title": "Тлеющая расщелина",
		"id": "cave",
		"text": "Между кочками земля проседает, и из трещины тянет сухим жаром — в топях, где всё гниёт от сырости. Мох по краям обуглен, а внизу, в темноте, что-то медленно дышит оранжевым светом. Камни у входа горячие на ощупь.",
		"options": [
			{"label": "Спуститься", "hint": "бой с хозяином пещеры, награда — дух огня", "action": "cave_enter"},
			{"label": "Пройти мимо", "result": "Вы уходите, а трещина за спиной ещё долго дышит в спину теплом."},
		],
	},
	# Появляется, только пока есть закрытые обереги, и не чаще раза за забег (см. _pick_event)
	{
		"title": "Тайник павшего дозорного",
		"act": 1,
		"id": "cache",
		"text": "Под корнями мёртвого дерева — кости в остатках лат Стражи. Рядом ящик, окованный медью, наполовину ушедший в трясину, и сумка с размокшими записками.",
		"options": [
			{"label": "Рыцарь вытаскивает ящик", "hint": "Рыцарь −6 HP → оберег до конца забега", "action": "cache_chest"},
			{"label": "Маг читает записки дозорного", "effects": [{"hp": -4, "who": "mage"}, {"echoes": 6}],
					"result": "Размокшие листы рассыпаются в пальцах, но последние строки ученик успевает запомнить — и они звучат знакомо, будто писал кто-то из вас."},
			{"label": "Оставить ящик мёртвому",
					"result": "Вы закрываете крышку и уходите. Пусть хоть что-то в этих топях останется на своём месте."},
		],
	},
	# --- События топей (тексты.md, утверждены 11 ноября) ---
	{
		"title": "Затонувшая повозка Стражи",
		"act": 1,
		"text": "Из чёрной жижи у старой гати торчит прогнивший борт казённой повозки с гербом-колоколом. Внутри — запечатанные тубусы с уставами, но доски под ногами уходят в трясину. Кто-то один должен полезть в ледяную воду, пока второй держит верёвку.",
		"options": [
			{"label": "В трясину лезет Рыцарь", "effects": [{"hp": -7, "who": "knight"}, {"card": "knight", "rare": true}],
					"result": "Латы тянут ко дну, ледяная жижа сводит плечи судорогой, но стражник вытаскивает на берег старый устав."},
			{"label": "В воду спускается Маг", "effects": [{"hp": -5, "who": "mage"}, {"card": "mage"}, {"remove": "mage"}],
					"result": "Продрогший до костей ученик выбирается из трясины, оставив на дне размокшие черновики ради уцелевшего свитка стихий."},
			{"label": "Не лезть", "result": "Повозка уходит в жижу ещё на ладонь. Через год о ней никто не вспомнит."},
		],
	},
	{
		"title": "Фонарь у переправы",
		"act": 1,
		"text": "На покосившемся столбе посреди затопленных руин горит старый фонарь Стражи, а внутри вместо масла бьётся пойманный осколок бури. Его неровный свет режет глаза, но в тенях на мокрых плитах проступают забытые формулы ордена и строевые метки.",
		"options": [
			{"label": "Маг вглядывается в свет осколка", "effects": [{"hp": -6, "who": "mage"}, {"card": "mage", "rare": true}],
					"result": "От резкого сияния немеют виски, но в гуле стекла складывается чистая формула грозового разряда."},
			{"label": "Рыцарь чинит заслонку фонаря", "effects": [{"gold": -20}, {"card": "knight"}, {"hp": 7, "who": "knight"}],
					"result": "Заменив лопнувшее кольцо парой монет из кошеля, латник возвращает фонарю ровный свет и переводит дух у знакомого маяка."},
			{"label": "Обойти столб стороной",
					"result": "Вы оставляете гудящий фонарь догорать в тумане — в этих топях чужой свет редко светит даром."},
		],
	},
	{
		"title": "Склад болотного газа",
		"act": 1,
		"text": "За полусгнившим частоколом брошенной заставы темнеет навес, под которым свалены бочки со светящимися зелёными щелями. Между ними блестит рассыпанная казна гарнизона и лежат перевязочные сумки, но одна из бочек уже тихо шипит.",
		"options": [
			{"label": "Рыцарь выносит казну", "effects": [{"hp": -5, "who": "knight"}], "chance": 0.6,
					"win": {"effects": [{"gold": 35}, {"card": "knight"}],
							"result": "Задержав дыхание в едком пару, латник выволакивает ящик с жалованьем и прихватывает со стойки забытое оружие."},
					"lose": {"effects": [{"hp": -3, "who": "knight"}, {"gold": 15}],
							"result": "Гнилой обруч лопается с резким хлопком, обжигая руки сквозь перчатки, и в спешке удаётся унести лишь горсть монет."}},
			{"label": "Маг отводит газ от сумок лекаря",
					"effects": [{"hp": -4, "who": "mage"}, {"gold": -10}, {"hp": 8, "who": "knight"}, {"remove": "mage"}],
					"result": "Ученик разгоняет ядовитое облако и достаёт из-под навеса чистые бинты для напарника."},
			{"label": "Не трогать бочки и уйти",
					"result": "Вы благоразумно отступаете по гати, оставляя казённое серебро гнить в зелёном тумане."},
		],
	},
	{
		"title": "Круг грибов",
		"act": 1,
		"text": "На плоском камне среди камышей выросло кольцо бледно-бирюзовых грибов, от которых вода вокруг мелко дрожит. Воздух пахнет озоном и золой, как в день, когда рухнула башня ордена. Сила в камне избавит от старых ошибок, но даром не отпустит.",
		"options": [
			{"label": "В круг входит Маг", "effects": [{"hp": -6, "who": "mage"}, {"remove": "mage"}, {"card": "mage"}],
					"result": "Холодный ток прошивает пальцы до локтей, выжигая из памяти лишние школьные прописи и оставляя только ясную злость бури."},
			{"label": "Рыцарь выжигает грибницу смолой", "effects": [{"gold": -15}, {"remove": "knight"}, {"hp": 5, "who": "mage"}],
					"result": "Пропитанная смолой пакля сжигает светящиеся шляпки дотла, и дышать у камня сразу становится легче."},
			{"label": "Перешагнуть мимо круга",
					"result": "Споры тихо оседают на сапоги, но вы уходите прежде, чем камень под ногами начинает гудеть."},
		],
	},
	{
		"title": "Пост у колокола",
		"act": 1,
		"text": "На краю мёртвой рощи сохранилась каменная караулка с треснувшим малым колоколом на балке и сухим очагом внутри. На стене углём выведены имена последнего дозора, который так и не дождался смены.",
		"options": [
			{"label": "Развести огонь из старых щитов", "effects": [{"hp": 4, "who": "all"}],
					"result": "Рассохшиеся щиты дают неожиданно много тепла, и за час у очага уходит накопленная в болоте ломота."},
			{"label": "Рыцарь ударяет в малый колокол", "effects": [{"hp": -6, "who": "knight"}, {"card": "knight", "rare": true}],
					"result": "Глухой удар отдаётся в висках тяжёлым звоном, пробуждая ту самую злость, с которой когда-то шли на прорыв."},
			{"label": "Маг разбирает архив караулки",
					"effects": [{"hp": -4, "who": "mage"}, {"gold": -10}, {"card": "mage"}, {"card": "knight"}],
					"result": "Среди промокших донесений находятся записи о старых бродах и строевых приёмах местного гарнизона."},
		],
	},
	# ---------- Новые события (тз-события.md, 19 ноября) ----------
	{
		"title": "Следы вожака",
		"id": "tracks",
		"need": "event_elite",
		"min_row": 1,
		"text": "Поперёк тропы — свежие следы, слишком большие для обычной твари. Кора на деревьях содрана на высоте плеча, в грязи темнеют клочья шерсти. Следы уходят в сторону от дороги.",
		"options": [
			{"label": "Выследить", "hint": "бой с элитой; награда — реликвия на выбор", "effects": [{"fight": "elite"}],
					"result": "Отряд сворачивает с тропы."},
			{"label": "Запомнить, куда ведут", "effects": [{"fog": 1}],
					"result": "Вы зарисовываете тропы на краю карты. Теперь видно дальше."},
			{"label": "Уйти", "result": "Следы остаются за спиной. Пусть хозяин их ищет кого-то другого."},
		],
	},
	{
		"title": "Караван без возницы",
		"text": "На обочине стоит повозка с клеймом-шестернёй. Лошадей нет, возницы нет, только ящики под просмолённой тканью. Один ящик окован железом и заперт тяжёлым замком.",
		"options": [
			{"label": "Сбить замок", "effects": [{"hp": -8, "who": "knight"}, {"relic_pick": 3}],
					"result": "Замок поддаётся с третьего удара, и пружина ловушки рвёт латнику руку. В ящике — то, что технари везли не на продажу."},
			{"label": "Забрать то, что сверху", "effects": [{"gold": 30}],
					"result": "Под тканью — монеты в промасленной бумаге. Кто-то платил за молчание."},
			{"label": "Не трогать", "result": "Чужой груз — чужие беды."},
		],
	},
	{
		"title": "Раненый дозорный",
		"text": "У поваленного столба сидит дозорный Стражи. Плащ в крови, меч на коленях. «Донесите письмо до заставы, — шепчет он. — Я знаю здешние тропы. Всё расскажу».",
		"options": [
			{"label": "Перевязать и выслушать", "effects": [{"gold": -15}, {"hp": 6, "who": "all"}, {"fog": 1}],
					"result": "Он рисует пальцем тропы на вашей карте и отдаёт остаток своего пайка."},
			{"label": "Забрать его меч", "effects": [{"card": "knight", "rare": true}, {"wound": "mage"}],
					"result": "Дозорный не сопротивляется. Только смотрит на мага так долго, что тот потом не может уснуть."},
			{"label": "Оставить", "result": "Его голос долго звучит позади."},
		],
	},
	{
		"title": "Точильный камень у брода",
		"text": "У брода лежит плоский камень Стражи, весь в бороздах от клинков. Рядом на столбе — выцветшие знаки ордена, ещё читаемые.",
		"options": [
			{"label": "Наточить клинок", "effects": [{"upgrade": "knight"}], "result": "Клинок снова звенит, как в день присяги."},
			{"label": "Перечертить знаки", "effects": [{"upgrade": "mage"}], "result": "Знаки ордена отзываются в пальцах забытым теплом."},
		],
	},
	{
		"title": "Колодец желаний",
		"text": "Старый колодец, на дне — медный отблеск. Над срубом вырезано: «Бросивший — получит». Буквы стёрты руками.",
		"options": [
			{"label": "Бросить монеты", "effects": [{"gold": -25}], "chance": 0.5,
					"win": {"effects": [{"relic_pick": 3}], "result": "Из темноты поднимается то, что когда-то бросили другие."},
					"lose": {"effects": [], "result": "Монеты звякают о дно. Больше ничего."}},
			{"label": "Напиться", "effects": [{"hp": 8, "who": "all"}], "result": "Вода с привкусом меди, но холодная и чистая."},
		],
	},
	{
		"title": "Дозор у священного дуба",
		"branch": "forest",
		"text": "Тропу преграждают Хранители Рощи. Маски неподвижны, копья опущены — пока. Старший указывает на дуб, у корней которого лежат дары.",
		"options": [
			{"label": "Поклониться и оставить дар", "effects": [{"gold": -20}, {"keepers": "calm"}],
					"result": "Маски склоняются. До конца пути Хранители бьют вас без прежней злобы."},
			{"label": "Отказаться", "hint": "бой с Хранителями", "effects": [{"fight": "grove_patrol"}],
					"result": "Копья поднимаются."},
			{"label": "Обойти по бурелому", "effects": [{"hp": -4, "who": "all"}],
					"result": "Ветви рвут одежду, но Хранители так и не двинулись с места."},
		],
	},
	{
		"title": "Капище масок",
		"branch": "forest",
		"text": "На ветвях висят пустые деревянные маски. Одна светится изнутри бледной зеленью. Под деревом — плоский камень для подношений.",
		"options": [
			{"label": "Надеть светящуюся маску", "effects": [{"relic": 1}],
					"result": "Маска прирастает к лицу на миг, потом отпускает. Что-то от неё осталось с вами."},
			{"label": "Оставить подношение", "hint": "отдать карту → реликвия на выбор", "effects": [{"remove": "random"}, {"relic_pick": 3}],
					"result": "Роща принимает дар. Взамен маски показывают то, что они хранили."},
			{"label": "Уйти", "result": "Маски провожают взглядом пустых прорезей."},
		],
	},
	{
		"title": "Пасека в дупле",
		"branch": "forest",
		"text": "В огромном дупле — дикий улей. Соты висят до самой земли, мёд стекает по коре. Пчёлы гудят глухо и зло.",
		"options": [
			{"label": "Достать соты", "effects": [{"hp": -6, "who": "knight"}, {"hp": 10, "who": "all"}],
					"result": "Латы не спасают от каждого жала, но мёд того стоил."},
			{"label": "Выкурить пчёл", "effects": [{"hp": -1, "who": "all"}, {"gold": 25}],
					"result": "Под сотами — чей-то давний тайник с монетами."},
			{"label": "Не трогать", "result": "Гул затихает за спиной."},
		],
	},
	{
		"title": "Заблудившийся Саженец",
		"branch": "forest",
		"text": "У тропы стоит Саженец — кукла из живых ветвей с маленькой резной маской. Он смотрит то на вас, то на чащу, будто не знает дороги.",
		"options": [
			{"label": "Отвести к своим", "effects": [{"hp": -3, "who": "all"}, {"keepers": "fewer"}],
					"result": "На опушке его забирают молча. В следующий раз Хранителей выйдет меньше."},
			{"label": "Срубить", "effects": [{"card": "mage"}],
					"result": "Из сердцевины сочится светлый сок. Маг запоминает, как он пахнет."},
			{"label": "Пройти мимо", "result": "Саженец ещё долго стоит у тропы."},
		],
	},
	{
		"title": "Насос технарей",
		"branch": "bog",
		"text": "Ржавый насос всё ещё гудит. В стеклянной колбе на нём бьётся огонёк — запертый дух, совсем слабый.",
		"options": [
			{"label": "Разбить колбу", "chance": 0.5,
					"win": {"effects": [{"card": "random", "rare": true}], "result": "Огонёк кружит над отрядом и оставляет в памяти чужой приём."},
					"lose": {"effects": [{"echoes": 10}], "result": "Огонёк гаснет в воздухе, но его эхо уходит с вами."}},
			{"label": "Забрать колбу", "effects": [{"relic": 1}], "result": "Колба тёплая и тихо гудит в сумке."},
			{"label": "Уйти", "result": "Насос гудит вам вслед."},
		],
	},
	{
		"title": "Утопленник шепчет",
		"branch": "bog",
		"text": "Из трясины поднимается лицо, белое, как ил. Губы шевелятся: «Отдай то, что тянет тебя вниз. Я возьму».",
		"options": [
			{"label": "Выслушать", "effects": [{"hp": -5, "who": "random"}, {"remove": "random"}],
					"result": "Холодная рука касается запястья. Что-то уходит вместе с ней."},
			{"label": "Заткнуть уши", "result": "Шёпот стихает, только круги по воде."},
		],
	},
	{
		"title": "Дым над топью",
		"branch": "bog",
		"min_row": 1,
		"text": "Над кочками поднимается жирный дым. Гоблины жарят что-то на костре и спорят из-за мешка с добычей.",
		"options": [
			{"label": "Напасть", "hint": "бой с гоблинами, потом +40 золота", "effects": [{"gold_after": 40}, {"fight": "gang"}],
					"result": "Гоблины хватаются за дубины."},
			{"label": "Подкрасться и стащить мешок", "chance": 0.6,
					"win": {"effects": [{"card": "random"}, {"gold": 15}], "result": "Мешок тяжёлый и звенит. Гоблины даже не обернулись."},
					"lose": {"effects": [{"fight": "gang"}], "result": "Сучок трещит под сапогом. Гоблины оборачиваются."}},
			{"label": "Обойти", "result": "Дым ещё долго висит над топью."},
		],
	},
	# Секрет акта 2 (ветка Тракт): по своему шансу, раз за забег (см. _pick_event)
	{
		"title": "Кипящий источник",
		"art": "boiling_spring",
		"id": "spring",
		"text": "Среди пепла бьёт ключ — вода в нём кипит, хотя огня рядом нет. Пар поднимается столбом и вдруг складывается в широкие плечи и тяжёлую голову. Над водой гудит, как в котле, у которого заклинило крышку. Ошпаренные крабы пятятся от края.",
		"options": [
			{"label": "Подойти к воде", "hint": "бой с хозяином источника, награда — дух пара", "action": "spring_enter"},
			{"label": "Обойти стороной", "result": "Вы обходите источник по широкой дуге. Пар провожает вас, пока не теряется в пепле."},
		],
	},
	# ---------- Акт 2 «Пепельный тракт» (21 ноября) ----------
	# «branch»: "tract" — левая ветка (Тракт), "deep" — правая (Подземье); без ветки — обе. Акт 3 их тоже берёт.
	{
		"title": "Застава мародёров",
		"art": "marauder_toll",
		"branch": "tract",
		"text": "Поперёк тракта — перевёрнутая телега и мешки с песком. Из-за них поднимается человек с самострелом. «Дорога платная. Платите — проходите. Не платите — оставляете всё».",
		"options": [
			{"label": "Заплатить", "effects": [{"gold": -30}],
					"result": "Мародёр пересчитывает монеты дважды и откатывает телегу ровно настолько, чтобы протиснуться боком."},
			{"label": "Нанять его проводником", "effects": [{"gold": -20}, {"fog": 2}],
					"result": "За серебро он показывает, где тракт обвалился, а где лава ушла под корку. Врёт он меньше, чем ожидалось."},
			{"label": "Прорваться", "hint": "бой с мародёрами, потом +35 золота", "effects": [{"gold_after": 35}, {"fight": "tr_scavengers"}],
					"result": "Первая бутыль с маслом разбивается у ваших ног."},
		],
	},
	{
		"title": "Сгоревший обоз",
		"art": "burnt_convoy",
		"branch": "tract",
		"text": "Десяток повозок стоит, как стоял, — только от них остались чёрные рёбра. Пепел ещё тёплый. Под днищем головной телеги поблёскивает окованный сундук казначея.",
		"options": [
			{"label": "Рыцарь разгребает угли", "effects": [{"hp": -6, "who": "knight"}], "chance": 0.55,
					"win": {"effects": [{"relic": 1}], "result": "Сундук обжигает руки сквозь перчатки, но замок уже расплавился. Внутри — вещь, которую казначей вёз отдельно от денег."},
					"lose": {"effects": [{"gold": 20}], "result": "Сундук пуст: его вскрыли до вас. В золе удаётся наскрести горсть оплавленных монет."}},
			{"label": "Маг читает уцелевшие накладные", "effects": [{"hp": -3, "who": "mage"}, {"card": "mage"}, {"remove": "mage"}],
					"result": "Большая часть листов рассыпается в руках. На одном — расчёт, как гасить огонь паром. Старые записи мага теперь кажутся лишними."},
			{"label": "Не тревожить мёртвых", "result": "Вы обходите обоз по обочине. Пепел за спиной оседает на следы."},
		],
	},
	{
		"title": "Тёплые ключи",
		"art": "warm_springs",
		"branch": "tract",
		"text": "Между камнями парят мелкие озерца. Вода тёплая, пахнет серой, на дне шевелятся тени — то ли водоросли, то ли что-то с щупальцами. После пепла и жара она манит.",
		"options": [
			{"label": "Отдохнуть в воде", "chance": 0.65,
					"win": {"effects": [{"heal_pct": 30, "who": "all"}], "result": "Тепло выгоняет из суставов усталость тракта. Тени на дне держатся в стороне."},
					"lose": {"effects": [{"fight": "tr_springs"}], "result": "Купол медузы поднимается прямо под магом. Вода вскипает."}},
			{"label": "Набрать воды во фляги", "effects": [{"heal_pct": 12, "who": "all"}],
					"result": "Горькая, но чистая вода. Хватит до следующего привала."},
			{"label": "Идти дальше", "result": "Пар остаётся за спиной."},
		],
	},
	{
		"title": "Беглецы с тракта",
		"art": "refugees",
		"branch": "tract",
		"text": "У придорожного камня жмутся трое: старик, женщина и мальчишка с узлом. Их обоз сгорел, лошадей увели мародёры. «Мы не просим многого. Хотя бы дорогу назад».",
		"options": [
			{"label": "Поделиться припасами", "effects": [{"gold": -15}, {"echoes": 10}, {"fog": 1}],
					"result": "Старик долго благодарит и рассказывает, где на тракте устроили засаду. Мальчишка провожает вас взглядом до поворота."},
			{"label": "Взять плату за охрану", "effects": [{"gold": 25}, {"hp": -4, "who": "all"}],
					"result": "Вы провожаете их до перевала и отбиваетесь от падальщиков. У женщины в узле нашлось серебро — последнее."},
			{"label": "Указать дорогу и уйти", "result": "Они уходят назад, к болотам. Может быть, дойдут."},
		],
	},
	{
		"title": "Журнал лаборатории",
		"art": "lab_journal",
		"branch": "deep",
		"text": "В пустом зале — стол, заваленный бумагами, и кресло с ремнями. Под стеклом — толстый журнал в кожаном переплёте. Последняя запись обрывается на полуслове: «Сфера номер девять не держит. Если вы это читаете —».",
		"options": [
			{"label": "Маг читает журнал", "effects": [{"hp": -5, "who": "mage"}, {"card": "mage", "rare": true}],
					"result": "Формулы технарей режут глаза, как свет сферы. Но одна из них — о том, как держать стихию в клетке, — понятна сразу."},
			{"label": "Рыцарь вскрывает шкаф с инструментом", "effects": [{"upgrade": "knight"}],
					"result": "Клещи, напильники, точило на ножном ходу — всё ещё в смазке. Через час клинок рыцаря держит кромку лучше прежнего."},
			{"label": "Уйти", "result": "Кресло с ремнями провожает вас пустыми подлокотниками."},
		],
	},
	{
		"title": "Треснувшая сфера",
		"art": "cracked_sphere",
		"branch": "deep",
		"min_row": 1,
		"text": "В нише стоит сфера в железной клетке. Стекло треснуло, изнутри бьётся вода — живая, с двумя бирюзовыми огоньками. Дух почти вырвался. Рядом дремлет сферник-сторож.",
		"options": [
			{"label": "Разбить сферу", "hint": "бой; разобьёшь сферу духа до победы — он твой", "effects": [{"fight": "dp_half_spirit"}],
					"result": "Стекло лопается, сторож вскидывается. Дух выплёскивается наружу — и не понимает, кто ему враг."},
			{"label": "Прислушаться к духу", "effects": [{"echoes": 8}],
					"result": "Сквозь стекло дух говорит о небе, которого не видел сотню лет. Вы запомните это."},
			{"label": "Не будить сторожа", "result": "Вы проходите мимо на цыпочках."},
		],
	},
	{
		"title": "Чёрное озеро",
		"art": "black_lake",
		"branch": "deep",
		"text": "Подземное озеро гладкое, как стекло. На дне, в двух саженях, что-то отсвечивает медью. Слепые рыбы кружат у берега и не боятся света.",
		"options": [
			{"label": "Рыцарь ныряет за блеском", "effects": [{"hp": -8, "who": "knight"}, {"relic": 1}],
					"result": "Ледяная вода выжимает дыхание, латы тянут вниз. Но медная вещь в руке — не камень."},
			{"label": "Напиться и отдохнуть", "chance": 0.6,
					"win": {"effects": [{"heal_pct": 25, "who": "all"}], "result": "Вода холодная и сладкая. Впервые за много дней не пахнет гарью."},
					"lose": {"effects": [{"heal_pct": 10, "who": "all"}, {"wound": "mage"}], "result": "Слепыш выныривает у самого берега. Маг отскакивает, но зубы успевают зацепить руку."}},
			{"label": "Обойти берегом", "result": "Рыбы провожают вас до поворота туннеля."},
		],
	},
	{
		"title": "Мастерская технарей",
		"art": "workshop",
		"branch": "deep",
		"text": "Станок ещё крутится: паровой привод стучит, ремень шлёпает по колесу. На верстаке — заготовки, ключи, пустые кожухи сферников. Никого. Только Ремонтник в углу чинит сам себя.",
		"options": [
			{"label": "Перековать оружие", "effects": [{"gold": -25}, {"upgrade": "knight"}, {"upgrade": "mage"}],
					"result": "Уголь для горна стоит денег даже здесь. Но станок делает то, на что у кузнеца ушла бы неделя."},
			{"label": "Разобрать станок на детали", "effects": [{"gold": 30}],
					"result": "Латунь и медь на поверхности стоят хорошо. Ремонтник смотрит на вас линзой и ничего не говорит."},
			{"label": "Уйти", "result": "Привод стучит вам вслед."},
		],
	},
	{
		"title": "Старатель Венца",
		"art": "prospector",
		"act": 2,
		"text": "Культист в пыльной рясе тащит за спиной сферу с огненным духом. Увидев вас, он не бежит: садится на камень и вытирает лоб. «Я только носильщик. Хотите — купите у меня. Хотите — отнимите. Мне всё равно, сфера тяжёлая».",
		"options": [
			{"label": "Купить пепельный кристалл", "effects": [{"gold": -30}, {"relic": 1}],
					"result": "Из-под рясы он достаёт кристалл с бирюзовой трещиной внутри. Тёплый, как живой."},
			{"label": "Отнять кирку", "effects": [{"hp": -4, "who": "knight"}, {"card": "knight"}],
					"result": "Старатель отбивается вяло и отдаёт кирку. Она тяжелее, чем выглядит, и бьёт как надо."},
			{"label": "Отпустить", "result": "Он кланяется и тащит сферу дальше, к жерлу."},
		],
	},
	{
		"title": "Пепельный дождь",
		"art": "ash_rain",
		"act": 2,
		"text": "Небо темнеет, и с него начинает сыпаться серый пепел. Сначала редкий, потом всё гуще. Дышать трудно, дорогу засыпает на глазах. Рядом — пустой каменный навес.",
		"options": [
			{"label": "Переждать под навесом", "effects": [{"heal_pct": 15, "who": "all"}],
					"result": "Несколько часов отдыха. Когда пепел перестаёт, дорогу не узнать — но вы целы."},
			{"label": "Идти сквозь пепел", "effects": [{"hp": -4, "who": "all"}, {"fog": 2}, {"echoes": 5}],
					"result": "Глаза слезятся, в горле песок. Зато сверху, с гребня, видно далеко вперёд — пепел смыл дымку."},
		],
	},
	{
		"title": "Алтарь у жерла",
		"art": "crater_altar",
		"act": 2,
		"min_row": 3,
		"text": "На чёрной скале — алтарь из костей и шлака. На нём лежит венец, точь-в-точь как над головами культистов, только больше. Земля под ним дрожит в такт с вулканом.",
		"options": [
			{"label": "Маг касается венца", "effects": [{"hp": -8, "who": "mage"}, {"card": "mage", "rare": true}, {"wound": "mage"}],
					"result": "Венец холодный, как лёд, и шепчет. Маг отдёргивает руку с новой формулой в голове и ожогом, который не заживает."},
			{"label": "Рыцарь разбивает алтарь", "effects": [{"hp": -5, "who": "knight"}, {"remove": "knight"}, {"echoes": 6}],
					"result": "Кости хрустят под молотом, шлак разлетается. Вместе с алтарём из памяти рыцаря уходит что-то тяжёлое."},
			{"label": "Уйти", "result": "Вы уходите, не оборачиваясь. Дрожь в земле стихает не сразу."},
		],
	},
	{
		"title": "Мародёр-торговец",
		"art": "marauder_trader",
		"act": 2,
		"text": "У костра — тощий человек в латаном плаще, рядом мешок с добычей. «Не стреляйте, я торгую. Мечи, свитки, снадобья — всё честно снято с мёртвых. Ну, почти честно».",
		"options": [
			{"label": "Купить свиток", "effects": [{"gold": -40}, {"card": "mage", "rare": true}],
					"result": "Свиток в пятнах сажи, но формула внутри цела."},
			{"label": "Купить клинок", "effects": [{"gold": -40}, {"card": "knight", "rare": true}],
					"result": "Клинок с чужим клеймом. Бывший хозяин, видимо, был мастером."},
			{"label": "Купить снадобья", "effects": [{"gold": -20}, {"heal_pct": 30, "who": "all"}],
					"result": "Горькое, мутное, но действует сразу."},
			{"label": "Уйти", "result": "«Заходите ещё», — кричит он вслед. Как будто здесь есть куда заходить."},
		],
	},
]

const CARD_SCALE: float = 0.8   # карты-награды на экране итога
const NAMES: Dictionary = {   # как называть героя: кто / кому / кого
	"knight": ["Рыцарь", "Рыцарю", "Рыцаря"],
	"mage": ["Маг", "Магу", "Мага"],
	"random": ["случайный герой", "случайному герою", "случайного героя"],
}

var _column: VBoxContainer
var _title: String = ""   # название события — показываем и на экране с итогом
# Что происходит сейчас (общий разбор шагов)
var _steps: Array = []                 # шаги, которые ещё не выполнены
var _story_text: String = ""           # текст итога
var _lines: Array[String] = []         # что получили и чем заплатили — строками под текстом
var _won_cards: Array[Dictionary] = [] # карты-награды: {"card", "color"} — показываем картинками
var _random: RunHero = null            # «случайный герой» этого выбора (один на все шаги)
var _last_remove: String = ""          # чью карту сейчас убирают (для тестов)
var fought: bool = false               # выбор увёл в бой (для тестов)
var relic_offer: Array[RelicData] = [] # реликвии на выбор, которые сейчас показаны (для тестов)


func _ready() -> void:
	Hints.offer(self, "event")   # при первом заходе — подсказка слева внизу (scripts/tutorial/hints.gd)
	var event: Dictionary = _pick_event()
	_title = event["title"]
	_build_book(event_art(event))
	_page_header()
	_column.add_child(_story(event["text"]))
	for option: Dictionary in event["options"]:
		_column.add_child(_choice_plaque(option))


# ---------- Вид: раскрытая книга (макет Gemini, 21 ноября) ----------
# Слева — рисунок события в раме из тёмного дерева и латуни, справа — страница: название, текст, плашки выбора.
# Внизу — полоса отряда на коже. Пергамент и кожа — assets/textures/ui/ (скрипт src/build_book.py).
const INK := Color(0.2, 0.14, 0.09)            # чернила на пергаменте
const INK_ACCENT := Color(0.36, 0.24, 0.1)     # строки «что получили» — темнее латуни
const TITLE_INK := Color(0.32, 0.21, 0.1)      # заголовок страницы
const WOOD := Color(0.2, 0.14, 0.09)           # плашки и рама — тёмное дерево
const BRASS_EDGE := Color(0.62, 0.47, 0.24)    # латунная кромка
const BRASS_HOT := Color(0.95, 0.76, 0.4)      # кромка под курсором
const PLAQUE_TEXT := Color(0.93, 0.86, 0.72)   # надпись на плашке
const PAGE_SIZE := Vector2(550, 590)
const PAGE_TEXT_WIDTH: float = 450.0
const PARCHMENT: Texture2D = preload("res://assets/textures/ui/parchment.jpg")
const LEATHER: Texture2D = preload("res://assets/textures/ui/leather.jpg")
var _party_holder: Control


# Книга: кожаный фон, две страницы, полоса отряда внизу. _column — колонка правой страницы.
func _build_book(art: Texture2D) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = LEATHER
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.55, 0.55, 0.55)   # стол тёмный, книга светлее
	add_child(bg)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	add_child(outer)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(center)
	# Обложка: тёмная кожа с латунной кромкой, на ней две страницы
	var cover := PanelContainer.new()
	cover.add_theme_stylebox_override("panel", _cover_style())
	center.add_child(cover)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 6)   # корешок
	cover.add_child(spread)
	var left: PanelContainer = _page()
	spread.add_child(left)
	var lc := CenterContainer.new()
	left.add_child(lc)
	lc.add_child(_art_frame(art))
	var right: PanelContainer = _page()
	spread.add_child(right)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	right.add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 11)
	margin.add_child(_column)
	# Полоса отряда
	var strip := PanelContainer.new()
	var ss := StyleBoxFlat.new()   # тёмная кожа с латунной нитью по верху
	ss.bg_color = Color(0.1, 0.07, 0.05, 0.92)
	ss.border_color = BRASS_EDGE.darkened(0.2)
	ss.border_width_top = 2
	ss.content_margin_top = 8
	ss.content_margin_bottom = 8
	strip.add_theme_stylebox_override("panel", ss)
	outer.add_child(strip)
	_party_holder = CenterContainer.new()
	strip.add_child(_party_holder)
	_refresh_party()


func _refresh_party() -> void:
	if _party_holder == null:
		return
	UiKit.clear(_party_holder)
	_party_holder.add_child(UiKit.party_bar())


func _cover_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.09, 0.065)
	st.border_color = BRASS_EDGE.darkened(0.2)
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 24
	return st


# Страница: пергамент с тенью к корешку
func _page() -> PanelContainer:
	var page := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = PARCHMENT
	page.add_theme_stylebox_override("panel", st)
	page.custom_minimum_size = PAGE_SIZE
	return page


# Рама рисунка: тёмное дерево, латунная кромка в два ряда. Нет рисунка — большой знак события.
func _art_frame(art: Texture2D) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = WOOD
	st.border_color = BRASS_EDGE
	st.set_border_width_all(5)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(11)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 10
	st.shadow_offset = Vector2(4, 6)
	frame.add_theme_stylebox_override("panel", st)
	var inner := PanelContainer.new()
	var ist := StyleBoxFlat.new()
	ist.bg_color = Color(0.08, 0.06, 0.05)
	ist.border_color = BRASS_EDGE.darkened(0.35)
	ist.set_border_width_all(2)
	ist.set_content_margin_all(2)
	inner.add_theme_stylebox_override("panel", ist)
	frame.add_child(inner)
	if art != null:
		var pic := TextureRect.new()
		pic.texture = art
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
		inner.add_child(pic)
	else:
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
		holder.add_child(UiKit.icon_rect("event", 130, BRASS_EDGE))
		inner.add_child(holder)
	return frame


# Заголовок страницы с завитком-разделителем
func _page_header() -> void:
	var title: Label = UiKit.make_title(_title, 32, TITLE_INK)
	title.add_theme_color_override("font_shadow_color", Color(1, 0.95, 0.8, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 1)
	_column.add_child(title)
	var div := HBoxContainer.new()
	div.alignment = BoxContainer.ALIGNMENT_CENTER
	div.add_theme_constant_override("separation", 8)
	for i in 3:
		if i == 1:
			div.add_child(UiKit.icon_rect("star", 11, TITLE_INK))
			continue
		var bar := ColorRect.new()
		bar.color = Color(TITLE_INK, 0.6)
		bar.custom_minimum_size = Vector2(90, 2)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		div.add_child(bar)
	_column.add_child(div)


func _plaque_style(border: Color, width: int, glow: float) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = WOOD
	st.border_color = border
	st.set_border_width_all(width)
	st.set_corner_radius_all(4)
	st.content_margin_left = 16
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	if glow > 0.0:
		st.shadow_color = Color(BRASS_HOT, glow)
		st.shadow_size = 9
	return st


# Плашка выбора: название слева, цена и награда значками справа. small — скромная «Уйти».
func _plaque(text: String, on_pressed: Callable, chips: Array, tip: String = "", small: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _plaque_style(BRASS_EDGE, 2, 0.0))
	b.add_theme_stylebox_override("hover", _plaque_style(BRASS_HOT, 3, 0.35))
	b.add_theme_stylebox_override("pressed", _plaque_style(BRASS_HOT, 3, 0.15))
	b.add_theme_stylebox_override("disabled", _plaque_style(BRASS_EDGE.darkened(0.5), 2, 0.0))
	# Длинное название и много значков не влезают в строку — значки уходят во вторую строку, справа
	var chips_len: int = 0
	for c: Control in chips:
		chips_len += 3
		for l in c.find_children("*", "Label", true, false):
			chips_len += (l as Label).text.length()
	var two_lines: bool = not small and text.length() + chips_len > 40
	var width: float = maxf(190.0, text.length() * 10.0 + 70.0) if small else PAGE_TEXT_WIDTH
	b.custom_minimum_size = Vector2(width, 38 if small else (68 if two_lines else 46))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tip
	Sfx.bind_button(b)
	b.pressed.connect(on_pressed)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var chip_row: HBoxContainer = row
	if two_lines:
		var lines := VBoxContainer.new()
		lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lines.offset_left = 16
		lines.offset_right = -12
		lines.offset_top = 5
		lines.offset_bottom = -5
		lines.add_theme_constant_override("separation", 0)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.remove_child(row)
		b.add_child(lines)
		row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		lines.add_child(row)
		chip_row = HBoxContainer.new()
		chip_row.alignment = BoxContainer.ALIGNMENT_END
		chip_row.add_theme_constant_override("separation", 8)
		chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(chip_row)
	var name_label: Label = UiKit.make_label(text, 17 if small else 19, PLAQUE_TEXT)
	name_label.add_theme_font_override("font", UiKit.font_title())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not small else Control.SIZE_SHRINK_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if small:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(name_label)
	for c: Control in chips:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip_row.add_child(c)
	if small:
		row.add_child(UiKit.make_label("→", 17, PLAQUE_TEXT))
	return b


# Главная кнопка страницы («Дальше», «В бой»): крупная латунная плашка
func _main_button(text: String, on_pressed: Callable) -> Button:
	var b: Button = _plaque(text, on_pressed, [], "", true)
	b.custom_minimum_size = Vector2(230, 44)
	b.add_theme_stylebox_override("normal", _plaque_style(BRASS_HOT, 3, 0.25))
	return b


# Плашка выбора события: значки цены и награды, нельзя нажать — тусклая с замком
func _choice_plaque(option: Dictionary) -> Button:
	var plain: bool = not option.has("action") and not option.has("chance") and option.get("effects", []).is_empty() \
			and option.get("hint", "") == ""
	var b: Button = _plaque(option["label"], _choose.bind(option), [] if plain else option_chips(option),
			option_label(option), plain)
	var why: String = blocked_reason(option)
	if why != "":
		b.disabled = true
		b.tooltip_text = why
		b.modulate = Color(1, 1, 1, 0.55)
		var row: Node = b.get_child(0)
		if row is VBoxContainer:
			row = row.get_child(1)
		row.add_child(UiKit.icon_rect("lock", 16, PLAQUE_TEXT))
	return b


# Значки «цена → награда» для плашки. Подсказка (hint) и шанс — коротким текстом.
func option_chips(option: Dictionary) -> Array:
	var chips: Array = []
	var costs: Array = []
	var gains: Array = []
	for st: Dictionary in option.get("effects", []):
		var c: Control = _step_chip(st)
		if c == null:
			continue
		if int(st.get("hp", 0)) < 0 or int(st.get("gold", 0)) < 0:
			costs.append(c)
		else:
			gains.append(c)
	if option.has("chance"):
		gains.append(_chip("help", "%d%%" % roundi(float(option["chance"]) * 100.0), PLAQUE_TEXT))
	if option.get("hint", "") != "" and gains.is_empty():
		gains.append(_chip("", option["hint"], PLAQUE_TEXT.darkened(0.15), 12))
	chips.append_array(costs)
	if not costs.is_empty() and not gains.is_empty():
		chips.append(_chip("", "→", PLAQUE_TEXT.darkened(0.2), 16))
	chips.append_array(gains)
	return chips


func _chip(icon_name: String, text: String, color: Color, size: int = 14) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if icon_name != "":
		row.add_child(UiKit.icon_rect(icon_name, 17, color))
	if text != "":
		var l: Label = UiKit.make_label(text, size, color, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	return row


# Один шаг значком (полное описание — во всплывающей подсказке плашки)
func _step_chip(st: Dictionary) -> Control:
	var who: String = String(st.get("who", ""))
	var whom: String = "" if who == "" or who == "all" or who == "random" else NAMES[who][1]
	if st.has("gold"):
		var g: int = int(st["gold"])
		return _chip("coin", ("+%d" % g) if g > 0 else ("−%d" % -g), UiKit.GOLD)
	if st.has("hp"):
		var n: int = int(st["hp"])
		var t: String = ("+%d" % n) if n > 0 else ("−%d" % -n)
		return _chip("heart", "%s %s" % [t, whom if whom != "" else (Loc.t("всем") if who == "all" else "")], UiKit.HP if n > 0 else PLAQUE_TEXT)
	if st.has("heal_pct"):
		return _chip("heart", "+%d%%" % int(st["heal_pct"]), UiKit.HP)
	if st.has("card"):
		var to: String = "?" if st["card"] == "random" else NAMES[st["card"]][1]
		return _chip("star" if st.get("rare", false) else "deck", to, UiKit.ECHO if st.get("rare", false) else PLAQUE_TEXT)
	if st.has("remove"):
		return _chip("discard", NAMES[st["remove"]][1] if st["remove"] != "random" else "", PLAQUE_TEXT)
	if st.has("upgrade"):
		return _chip("hammer", NAMES[st["upgrade"]][1], UiKit.BRASS)
	if st.has("echoes"):
		return _chip("echo", "+%d" % int(st["echoes"]), UiKit.ECHO)
	if st.has("relic") or st.has("relic_pick"):
		return _chip("relic", Loc.t("выбор") if st.has("relic_pick") else "", UiKit.BRASS)
	if st.has("wound"):
		return _chip("wound", NAMES[st["wound"]][1], PLAQUE_TEXT)
	if st.has("fog"):
		return _chip("zoom", "+%d" % int(st["fog"]), PLAQUE_TEXT)
	if st.has("fight"):
		return _chip("swords", Loc.t("бой"), PLAQUE_TEXT)
	if st.has("gold_after"):
		return _chip("coin", "+%d" % int(st["gold_after"]), UiKit.GOLD)
	var text: String = step_text(st)
	return null if text == "" else _chip("", text, PLAQUE_TEXT, 12)


const ART_DIR: String = "res://assets/textures/events/"
const ART_FALLBACK: String = "res://assets/textures/map_cards/card_event.jpg"
const ART_SIZE: float = 420.0   # сторона рисунка события на левой странице


# Рисунок события («art» — имя файла в assets/textures/events/ без .jpg); нет рисунка — null
static func event_art(e: Dictionary) -> Texture2D:
	var path: String = ART_DIR + String(e.get("art", "")) + ".jpg"
	if not e.has("art") or not ResourceLoader.exists(path):
		path = ART_FALLBACK   # своего рисунка нет — перекрёсток в тумане с карточки события на карте
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


# Случайное событие. Секретная расщелина — по своему шансу; «Тайник» — только если остались закрытые
# обереги; одно и то же событие в забеге второй раз не выпадает, пока есть невиданные.
func _pick_event() -> Dictionary:
	if Run.cave_possible() and Run.rng.randf() < Run.CAVE_EVENT_CHANCE:
		Run.cave_seen = true
		return event_by_id("cave")
	if Run.spring_possible() and Run.rng.randf() < Run.CAVE_EVENT_CHANCE:
		Run.spring_seen = true
		return event_by_id("spring")
	var pool: Array[Dictionary] = []
	for e in EVENTS:
		if event_allowed(e) and not Run.events_seen.has(e["title"]):
			pool.append(e)
	if pool.is_empty():   # все уже были — пусть повторяются
		for e in EVENTS:
			if event_allowed(e):
				pool.append(e)
	var event: Dictionary = pool[Run.rng.randi_range(0, pool.size() - 1)]
	Run.events_seen.append(event["title"])
	if event.get("id", "") == "cache":
		Run.cache_seen = true
	return event


static func event_allowed(e: Dictionary) -> bool:
	# Акт события: топи и лес — акт 1, тракт и подземье — акт 2 (и акт 3, который пока живёт на его содержимом)
	var ev_act: int = int(e.get("act", 2 if ["tract", "deep"].has(e.get("branch", "")) else (1 if e.has("branch") else 0)))
	if ev_act == 1 and Run.act != 1:
		return false
	if ev_act >= 2 and Run.act < 2:
		return false
	if e.has("branch"):
		var want: int = MapNode.FOREST if ["forest", "deep"].has(e["branch"]) else MapNode.BOG
		if Run.current_branch() != want:
			return false
	var here: int = Run.current.row if Run.current != null else 0
	if here < int(e.get("min_row", 0)):
		return false
	if e.get("need", "") == "event_elite" and (Run.event_elite() == null or Run.pending_event_elite != null):
		return false
	match e.get("id", ""):
		"cave", "spring":
			return false   # секреты — только по шансу в _pick_event
		"cache":
			return not Run.cache_seen and not Meta.closed_charms().is_empty()
		"cage":
			return Run.cage_spirit() != null
	return true


static func event_by_id(id: String) -> Dictionary:
	for e in EVENTS:
		if e.get("id", "") == id:
			return e
	return {}


# ---------- Подписи выборов ----------

# Надпись на кнопке: «В трясину лезет Рыцарь (Рыцарь −7 HP → Рыцарю редкая карта)»
static func option_label(option: Dictionary) -> String:
	var hint: String = option.get("hint", "")
	if hint == "":
		hint = describe(option.get("effects", []))
		if option.has("chance"):
			var win: int = roundi(float(option["chance"]) * 100.0)
			var parts: PackedStringArray = []
			if hint != "":
				parts.append(hint)
			parts.append("%d%%: %s" % [win, _gains_only(option["win"].get("effects", []))])
			parts.append("%d%%: %s" % [100 - win, _gains_only(option["lose"].get("effects", []))])
			hint = "; ".join(parts)
	return option["label"] if hint == "" else "%s  (%s)" % [option["label"], hint]


# «цена → награда» одной строкой
static func describe(steps: Array) -> String:
	var costs: PackedStringArray = []
	var gains: PackedStringArray = []
	for s: Dictionary in steps:
		var text: String = step_text(s)
		if text == "":
			continue
		if int(s.get("hp", 0)) < 0 or int(s.get("gold", 0)) < 0:
			costs.append(text)
		else:
			gains.append(text)
	if costs.is_empty():
		return Loc.t(" и ").join(gains)
	if gains.is_empty():
		return ", ".join(costs)
	return "%s → %s" % [", ".join(costs), Loc.t(" и ").join(gains)]


static func _gains_only(steps: Array) -> String:
	var parts: PackedStringArray = []
	for s: Dictionary in steps:
		parts.append(step_text(s))
	return Loc.t(" и ").join(parts)


# Один шаг словами
static func step_text(s: Dictionary) -> String:
	if s.has("hp"):
		var n: int = int(s["hp"])
		var amount: String = ("+%d HP" % n) if n > 0 else ("−%d HP" % -n)
		match s.get("who", "random"):
			"all":
				return Loc.t("каждому %s") % amount if n < 0 else Loc.t("%s каждому") % amount
			"random":
				return Loc.t("случайный герой %s") % amount
			var who:
				return "%s %s" % [NAMES[who][0], amount]
	if s.has("gold"):
		var g: int = int(s["gold"])
		return (Loc.t("+%d золота") % g) if g > 0 else (Loc.t("−%d золота") % -g)
	if s.has("card"):
		var kind: String = Loc.t("редкая карта") if s.get("rare", false) else Loc.t("карта")
		if s["card"] == "random":
			return Loc.t("%s случайному герою") % kind
		return "%s %s" % [NAMES[s["card"]][1], kind]
	if s.has("remove"):
		return Loc.t("убрать 1 карту %s") % NAMES[s["remove"]][2]
	if s.has("echoes"):
		return Loc.t("+%d Отзвуков") % int(s["echoes"])
	if s.has("relic"):
		return Loc.t("случайная реликвия")
	if s.has("relic_pick"):
		return Loc.t("реликвия на выбор")
	if s.has("fog"):
		return Loc.t("туман на карте отступит")
	if s.has("heal_pct"):
		return "+%d%% HP %s" % [int(s["heal_pct"]), Loc.t("каждому") if s.get("who", "all") == "all" else NAMES.get(s["who"], [Loc.t("герою")])[1]]
	if s.has("upgrade"):
		return Loc.t("улучшить карту %s") % NAMES[s["upgrade"]][2]
	if s.has("wound"):
		return Loc.t("%s — Рана") % NAMES[s["wound"]][1]
	if s.has("gold_after"):
		return Loc.t("+%d золота после боя") % int(s["gold_after"])
	if s.has("keepers"):
		return Loc.t("Хранители бьют слабее") if s["keepers"] == "calm" else Loc.t("Хранителей в следующем бою меньше")
	if s.has("fight"):
		return Loc.t("бой")
	return ""


# Почему выбор нельзя нажать (пусто — можно)
static func blocked_reason(option: Dictionary) -> String:
	var gold_cost: int = 0
	for s: Dictionary in option.get("effects", []):
		gold_cost -= mini(0, int(s.get("gold", 0)))
		if (s.has("relic") or s.has("relic_pick")) and not Run.can_take_relic():
			return Loc.t("Больше реликвий не унести")
		if s.has("upgrade") and Run.upgradable(_hero_static(s["upgrade"])).is_empty():
			return Loc.t("Нечего улучшать")
	if gold_cost > Run.gold:
		return Loc.t("Не хватает золота (нужно %d)") % gold_cost
	return ""


# ---------- Выбор ----------

func _choose(option: Dictionary) -> void:
	if option.has("action"):
		_special(option["action"])
		return
	_random = Run.random_hero()
	_lines.clear()
	_won_cards.clear()
	_steps = (option.get("effects", []) as Array).duplicate()
	_story_text = option.get("result", Loc.t("Отряд идёт дальше."))
	if option.has("chance"):
		var outcome: Dictionary = option["win"] if Run.rng.randf() < float(option["chance"]) else option["lose"]
		_steps.append_array(outcome.get("effects", []))
		_story_text = outcome.get("result", _story_text)
	_sound(_steps)
	_next_step()


# Выполняет шаги по очереди. «Убрать карту» и «реликвия на выбор» ждут выбора игрока, потом продолжают.
# «Бой» — последний шаг: после него экран боя, итог покажет экран награды.
func _next_step() -> void:
	while not _steps.is_empty():
		var s: Dictionary = _steps.pop_front()
		if s.has("fight"):
			Sfx.play("hit", 0.06)
			if s["fight"] == "elite":
				Run.start_event_battle(Run.event_elite(), true)
			else:
				Run.start_event_battle(Run.encounter_by_id(s["fight"]), false)
			fought = true
			return
		if s.has("relic_pick"):
			var offer: Array[RelicData] = Run.roll_relics(int(s["relic_pick"]))
			if offer.is_empty() or not Run.can_take_relic():
				_lines.append(Loc.t("Больше реликвий не унести"))
				continue
			_show_relic_pick(offer)
			return
		if s.has("remove"):
			var rh: RunHero = _random if s["remove"] == "random" else _hero(s["remove"])
			if rh.deck.size() <= Run.MIN_DECK_SIZE:
				_lines.append(Loc.t("%s: колода и так тонкая — убирать нечего") % NAMES[rh.data.id][0])
				continue
			_last_remove = rh.data.id
			var overlay: Control = DeckOverlay.open(self, Loc.t("Какую карту %s убрать?") % NAMES[rh.data.id][2],
					[{"title": rh.data.title, "color": rh.data.color, "cards": rh.deck}],
					Loc.t("Нажми на карту — она навсегда уйдёт из колоды."),
					func(_section: int, index: int) -> void: _remove(rh, index))
			# «Передумал» закрывает окно без выбора — тогда карта остаётся, а событие идёт дальше
			overlay.tree_exiting.connect(_removal_skipped.bind(rh))
			return
		_apply_step(s)
	_show_result(_story_text)


# Реликвия на выбор: три кнопки, взял одну — событие идёт дальше
func _show_relic_pick(offer: Array[RelicData]) -> void:
	relic_offer = offer
	UiKit.clear(_column)
	_page_header()
	_column.add_child(_story(Loc.t("Выбери реликвию:")))
	for r in offer:
		_column.add_child(_plaque(r.title, pick_relic.bind(r), [], "+ %s\n− %s" % [r.plus_text, r.minus_text]))


func pick_relic(r: RelicData) -> void:
	relic_offer.clear()
	Sfx.play("magic", 0.05)
	Run.take_relic(r)
	_lines.append(Loc.t("Реликвия «%s»\n+ %s\n− %s") % [Loc.t(r.title), r.plus_text, r.minus_text])
	_next_step()


func _remove(rh: RunHero, index: int) -> void:
	_last_remove = ""
	_lines.append(Loc.t("%s забывает «%s»") % [NAMES[rh.data.id][0], Loc.t(rh.deck[index].title)])
	rh.deck.remove_at(index)
	_next_step()


func _removal_skipped(rh: RunHero) -> void:
	if _last_remove == "":
		return   # карту уже выбрали
	_last_remove = ""
	_lines.append(Loc.t("%s: карту не убрали") % NAMES[rh.data.id][0])
	_next_step.call_deferred()


# Один шаг награды или цены
func _apply_step(s: Dictionary) -> void:
	if s.has("hp"):
		var n: int = int(s["hp"])
		for rh in _targets(s.get("who", "random")):
			var before: int = rh.hp
			if n < 0:
				rh.lose_hp(-n)
			else:
				Run.heal_hero(rh, n)
			var diff: int = rh.hp - before
			if diff != 0:
				_lines.append("%s: %s%d HP" % [Loc.t(rh.data.title), "+" if diff > 0 else "−", absi(diff)])
	elif s.has("gold"):
		var g: int = int(s["gold"])
		Run.gold = maxi(0, Run.gold + g)
		_lines.append((Loc.t("+%d золота") % g) if g > 0 else (Loc.t("−%d золота") % -g))
	elif s.has("card"):
		var rh: RunHero = _random if s["card"] == "random" else _hero(s["card"])
		var card: CardData = Run.event_card(rh, s.get("rare", false))
		if card != null:
			Run.add_card(rh, card)
			_lines.append(Loc.t("%s: новая карта «%s»") % [NAMES[rh.data.id][1], Loc.t(card.title)])
			_won_cards.append({"card": card, "color": rh.data.color})
	elif s.has("echoes"):
		Run.event_echoes += int(s["echoes"])
		_lines.append(Loc.t("+%d Отзвуков") % int(s["echoes"]))
	elif s.has("fog"):
		Run.fog_bonus += int(s["fog"])
		_lines.append(Loc.t("Туман на карте отступает: видно на %d ряда вперёд") % (Run.FOG_SIGHT + Run.fog_bonus))
	elif s.has("heal_pct"):
		for rh in _targets(s.get("who", "all")):
			var before: int = rh.hp
			Run.heal_hero(rh, ceili(rh.data.max_hp * int(s["heal_pct"]) / 100.0))
			if rh.hp != before:
				_lines.append("%s: +%d HP" % [Loc.t(rh.data.title), rh.hp - before])
	elif s.has("upgrade"):
		var rh: RunHero = _hero(s["upgrade"])
		var options: Array[int] = Run.upgradable(rh)
		if options.is_empty():
			_lines.append(Loc.t("%s: улучшать нечего") % NAMES[rh.data.id][0])
		else:
			var idx: int = options[Run.rng.randi_range(0, options.size() - 1)]
			var old_title: String = rh.deck[idx].title
			Run.upgrade_card(rh, idx, Run.rng.randi_range(1, 2))
			_lines.append("%s: «%s» → «%s»" % [NAMES[rh.data.id][0], old_title, Loc.t(rh.deck[idx].title)])
			_won_cards.append({"card": rh.deck[idx], "color": rh.data.color})
	elif s.has("wound"):
		var rh: RunHero = _hero(s["wound"])
		Run.add_wounds(rh, 1)
		_lines.append(Loc.t("%s: Рана в колоде") % NAMES[rh.data.id][0])
	elif s.has("gold_after"):
		Run.gold_after_battle += int(s["gold_after"])
	elif s.has("keepers"):
		if s["keepers"] == "calm":
			Run.keepers_calm = true
			_lines.append(Loc.t("Хранители Рощи до конца акта бьют на 1 слабее"))
		else:
			Run.keepers_fewer += 1
			_lines.append(Loc.t("В следующем бою с Хранителями их будет на одного меньше"))
	elif s.has("relic"):
		var offer: Array[RelicData] = Run.roll_relics(1)
		if offer.is_empty() or not Run.can_take_relic():
			_lines.append(Loc.t("Амулет рассыпается в руках — больше взять нечего"))
		else:
			Run.take_relic(offer[0])
			_lines.append(Loc.t("Реликвия «%s»\n+ %s\n− %s") % [Loc.t(offer[0].title), offer[0].plus_text, offer[0].minus_text])


# Кого касается шаг: knight / mage / all / random
func _targets(who: String) -> Array[RunHero]:
	var result: Array[RunHero] = []
	match who:
		"all":
			result.assign(Run.party)
		"random":
			result.append(_random)
		_:
			result.append(_hero(who))
	return result


# Звук по главному в выборе: карта или реликвия — магия, золото — монеты, лечение, иначе удар
func _sound(steps: Array) -> void:
	var kind: String = "hit"
	for s: Dictionary in steps:
		if s.has("card") or s.has("relic") or s.has("relic_pick") or s.has("echoes") or s.has("remove") or s.has("upgrade"):
			kind = "magic"
			break
		if int(s.get("gold", 0)) > 0:
			kind = "coin"
		elif int(s.get("hp", 0)) > 0 and kind == "hit":
			kind = "heal"
	if steps.is_empty():
		return
	Sfx.play(kind, 0.05)


# Особые выборы со своим кодом
func _special(action: String) -> void:
	match action:
		"cache_chest":
			Sfx.play("magic", 0.05)
			_hero("knight").lose_hp(6)
			var closed: Array[RelicData] = Meta.closed_charms()
			var charm: RelicData = closed[Run.rng.randi_range(0, closed.size() - 1)]
			Run.relics.append(charm.id)   # действует сразу, сверх мест
			Meta.unlock_charm(charm.id)   # и открыт на Полке навсегда
			_lines.assign([Loc.t("Рыцарь: −6 HP"), Loc.t("Оберег «%s»: %s\nОткрыт на Полке трофеев.") % [Loc.t(charm.title), charm.desc]])
			_won_cards.clear()
			_show_result(Loc.t("Жижа тянет за поножи, но окованный ящик выходит из грязи вместе с латником — внутри, в промасленной тряпице, лежит вещь дозора."))
		"cage_free":
			Sfx.play("hit", 0.06)
			for rh in Run.party:
				rh.lose_hp(5)
			Run.offer_spirit(Run.cage_spirit())
			Run.last_gold_reward = 0
			Run.goto(Run.REWARD_SCENE)   # там дух выбирает героя
		"cave_enter":
			Sfx.play("magic", 0.05)
			UiKit.clear(_column)
			_page_header()
			_column.add_child(_story(Loc.t("Чем глубже, тем суше воздух. Вода, что стекала по стенам, шипит и исчезает, не долетев до пола.")))
			_column.add_child(_main_button(Loc.t("В бой"), Run.enter_cave))
		"spring_enter":
			Sfx.play("magic", 0.05)
			UiKit.clear(_column)
			_page_header()
			_column.add_child(_story(Loc.t("Вода вскипает сильнее. Пар встаёт стеной, и из него на вас смотрят две бирюзовые искры.")))
			_column.add_child(_main_button(Loc.t("В бой"), Run.enter_spring))


static func _hero_static(hero_id: String) -> RunHero:
	for rh in Run.party:
		if rh.data.id == hero_id:
			return rh
	return Run.party[0]


# Герой отряда по id («knight» / «mage»); если такого нет — случайный
func _hero(hero_id: String) -> RunHero:
	for rh in Run.party:
		if rh.data.id == hero_id:
			return rh
	return Run.random_hero()


# Текст события — тёмные чернила прямо на пергаменте
func _story(text: String) -> Label:
	var label: Label = UiKit.make_text(text, 16, INK, PAGE_TEXT_WIDTH)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", UiKit.font_bold())
	return label


# Экран итога: текст, что получили и чем заплатили, новые карты картинками, отряд, «Дальше»
func _show_result(text: String) -> void:
	UiKit.clear(_column)
	_page_header()
	_column.add_child(_story(text))
	if not _lines.is_empty():
		var got: Label = UiKit.make_text("\n".join(_lines), 15, INK_ACCENT, PAGE_TEXT_WIDTH)
		got.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_column.add_child(got)
	if not _won_cards.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		for w: Dictionary in _won_cards:
			var b: Button = CardView.make_button(w["card"], w["color"])
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.pivot_offset = Vector2.ZERO
			b.scale = Vector2(CARD_SCALE, CARD_SCALE)
			var holder := Control.new()
			holder.custom_minimum_size = CardView.CARD_SIZE * CARD_SCALE
			holder.add_child(b)
			row.add_child(holder)
		_column.add_child(row)
	_refresh_party()
	_column.add_child(_main_button(Loc.t("Дальше"), Run.goto.bind(Run.MAP_SCENE)))

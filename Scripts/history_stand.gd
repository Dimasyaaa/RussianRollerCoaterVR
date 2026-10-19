extends Node3D

const PAGES := [
	{
		"title": "Русские горки",
		"text": "Предшественниками аттракциона были\nзимние горки в России: деревянные склоны\nпокрывали льдом, а вниз съезжали на санях.\nВо Франции название «русские горы»\nсохранилось и у современных горок.",
		"source": "Культура.РФ · culture.ru/s/vopros/russkie-gorki/"
	},
	{
		"title": "Колёса и рельсы",
		"text": "В 1817 году во Франции появились горки\nс колёсными вагонетками на направляющих.\nВ 1884 году в Кони-Айленде открылась\nSwitchback Railway Ламаркуса Томпсона.\nПозднее распространились замкнутые трассы.",
		"source": "Wikipedia · en.wikipedia.org/wiki/Roller_coaster"
	},
	{
		"title": "Горки парка",
		"text": "Здесь вагонетка проходит замкнутую трассу\nдлиной 736 метров через горную местность.\nНа спусках она ускоряется, на подъёмах —\nзамедляется, а на поворотах плавно наклоняется.\nПосле круга пассажир выходит у станции.",
		"source": "Замкнутый маршрут · 736 м"
	}
]

var page := 0

func _ready() -> void:
	$Previous.activated.connect(func(): _show_page(page-1))
	$Next.activated.connect(func(): _show_page(page+1))
	_show_page(0)

func _show_page(index: int) -> void:
	page = posmod(index,PAGES.size())
	$Title.text = PAGES[page].title
	$Description.text = PAGES[page].text
	$Source.text = PAGES[page].source
	$Page.text = "%d / %d" % [page+1,PAGES.size()]


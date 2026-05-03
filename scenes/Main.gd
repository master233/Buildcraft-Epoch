extends Node2D

@onready var bgm: AudioStreamPlayer = $BGM

# 建筑布置规则（视口 1280×720，等距视角）
# 缩放比：0.5（原图约 300px → 屏幕约 150px）
# 布局：以主基地为中心，资源建筑居上，功能建筑居下，防御塔置顶
const BUILDING_SCALE := 0.5

const BUILDINGS := {
	"home":       { "paths": ["res://asserts/image/building/home1.png",       "res://asserts/image/building/home2.png",       "res://asserts/image/building/home3.png"],       "pos": Vector2(640, 360), "display": "主基地" },
	"tower":      { "paths": ["res://asserts/image/building/tower1.png",      "res://asserts/image/building/tower2.png",      "res://asserts/image/building/tower3.png"],      "pos": Vector2(640, 180), "display": "远征塔" },
	"lumberyard": { "paths": ["res://asserts/image/building/lumberyard1.png", "res://asserts/image/building/lumberyard2.png", "res://asserts/image/building/lumberyard3.png"], "pos": Vector2(370, 260), "display": "伐木场" },
	"mine":       { "paths": ["res://asserts/image/building/Mine1.png",       "res://asserts/image/building/Mine2.png",       "res://asserts/image/building/Mine3.png"],       "pos": Vector2(910, 260), "display": "矿石场" },
	"tavern":     { "paths": ["res://asserts/image/building/Tavern1.png",     "res://asserts/image/building/Tavern2.png",     "res://asserts/image/building/Tavern3.png"],     "pos": Vector2(420, 480), "display": "酒馆"   },
	"research":   { "paths": ["res://asserts/image/building/research1.png",   "res://asserts/image/building/research2.png",   "res://asserts/image/building/research3.png"],   "pos": Vector2(850, 480), "display": "研究院" },
}

var _building_nodes: Dictionary = {}

func _input(_event: InputEvent) -> void:
	if not bgm.playing:
		bgm.play()

func _ready() -> void:
	bgm.stream = load("res://asserts/audio/bg1.wav")
	bgm.volume_db = 0.0
	bgm.play()
	call_deferred("_setup")

func _setup() -> void:
	var vp := get_viewport_rect().size

	# 背景：Sprite2D 直接在 Node2D 坐标系里渲染，scale 精确铺满视口
	var bg := Sprite2D.new()
	bg.texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	var tex := bg.texture
	var bg_scale := max(vp.x / tex.get_width(), vp.y / tex.get_height())
	bg.scale = Vector2(bg_scale, bg_scale)
	bg.position = vp / 2.0
	bg.z_index = -10
	add_child(bg)

	_place_buildings()

func _place_buildings() -> void:
	for key in BUILDINGS:
		var cfg = BUILDINGS[key]

		var container := Node2D.new()
		container.name = key.capitalize()
		container.position = cfg["pos"]
		add_child(container)

		var sprite := Sprite2D.new()
		sprite.texture = load(cfg["paths"][0])
		sprite.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
		container.add_child(sprite)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(120, 0)
		label.position = Vector2(-60.0, -(sprite.texture.get_height() * BUILDING_SCALE / 2.0) - 22.0)
		var ls := LabelSettings.new()
		ls.font_size = 14
		ls.font_color = Color.WHITE
		ls.outline_size = 3
		ls.outline_color = Color(0.0, 0.0, 0.0, 0.8)
		label.label_settings = ls
		container.add_child(label)

		_building_nodes[key] = { "level": 1, "sprite": sprite, "label": label }
		_refresh_label(key)

func upgrade_building(key: String) -> void:
	if not _building_nodes.has(key):
		return
	var state = _building_nodes[key]
	if state["level"] >= 3:
		return
	state["level"] += 1
	state["sprite"].texture = load(BUILDINGS[key]["paths"][state["level"] - 1])
	_refresh_label(key)

func _refresh_label(key: String) -> void:
	var state = _building_nodes[key]
	state["label"].text = "%s  Lv.%d" % [BUILDINGS[key]["display"], state["level"]]

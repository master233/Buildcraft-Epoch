extends Node2D

@onready var bgm: AudioStreamPlayer = $BGM
@onready var _wood_lbl: Label = $UI/WoodLbl
@onready var _ore_lbl: Label = $UI/OreLbl
@onready var _panel_dim: ColorRect = $UI/PanelDim
@onready var _panel_bg: ColorRect = $UI/PanelBg
@onready var _panel_border: ColorRect = $UI/PanelBorder
@onready var _panel_name_lbl: Label = $UI/PanelNameLbl
@onready var _panel_sep: ColorRect = $UI/PanelSep
@onready var _panel_info_lbl: Label = $UI/PanelInfoLbl
@onready var _upgrade_bg: ColorRect = $UI/UpgradeBg
@onready var _upgrade_lbl: Label = $UI/UpgradeLbl
@onready var _close_bg: ColorRect = $UI/CloseBg
@onready var _close_lbl: Label = $UI/CloseLbl

const BUILDING_SCALE := 0.75
const PRODUCE_INTERVAL := 5.0
const PRODUCE_RATES := [3, 6, 12]

const PANEL_RECT   := Rect2(470, 250, 340, 220)
const UPGRADE_RECT := Rect2(500, 412, 130, 44)
const CLOSE_RECT   := Rect2(650, 412, 130, 44)

const BUILDINGS := {
	"home": {
		"paths": ["res://asserts/image/building/home1.png", "res://asserts/image/building/home2.png", "res://asserts/image/building/home3.png"],
		"pos": Vector2(640, 360), "display": "主基地", "y_adj": 25,
		"upgrade_cost": [{"wood": 100, "ore": 80}, {"wood": 250, "ore": 200}],
		"produces": ""
	},
	"tower": {
		"paths": ["res://asserts/image/building/tower1.png", "res://asserts/image/building/tower2.png", "res://asserts/image/building/tower3.png"],
		"pos": Vector2(640, 180), "display": "远征塔", "y_adj": 0,
		"upgrade_cost": [{"wood": 80, "ore": 50}, {"wood": 200, "ore": 130}],
		"produces": ""
	},
	"lumberyard": {
		"paths": ["res://asserts/image/building/lumberyard1.png", "res://asserts/image/building/lumberyard2.png", "res://asserts/image/building/lumberyard3.png"],
		"pos": Vector2(370, 260), "display": "伐木场", "y_adj": 25,
		"upgrade_cost": [{"wood": 50, "ore": 20}, {"wood": 120, "ore": 60}],
		"produces": "wood"
	},
	"mine": {
		"paths": ["res://asserts/image/building/Mine1.png", "res://asserts/image/building/Mine2.png", "res://asserts/image/building/Mine3.png"],
		"pos": Vector2(910, 260), "display": "矿石场", "y_adj": 0,
		"upgrade_cost": [{"wood": 30, "ore": 50}, {"wood": 80, "ore": 130}],
		"produces": "ore"
	},
	"tavern": {
		"paths": ["res://asserts/image/building/Tavern1.png", "res://asserts/image/building/Tavern2.png", "res://asserts/image/building/Tavern3.png"],
		"pos": Vector2(420, 480), "display": "酒馆", "y_adj": 0,
		"upgrade_cost": [{"wood": 60, "ore": 40}, {"wood": 150, "ore": 100}],
		"produces": ""
	},
	"research": {
		"paths": ["res://asserts/image/building/research1.png", "res://asserts/image/building/research2.png", "res://asserts/image/building/research3.png"],
		"pos": Vector2(850, 480), "display": "研究院", "y_adj": 0,
		"upgrade_cost": [{"wood": 40, "ore": 60}, {"wood": 100, "ore": 150}],
		"produces": ""
	},
}

var _wood: int = 200
var _ore: int = 100
var _building_nodes: Dictionary = {}
var _produce_timer: float = 0.0
var _panel_key: String = ""
var _panel_visible: bool = false
var _panel_nodes: Array = []
var _upgrade_disabled: bool = false

func _ready() -> void:
	bgm.stream = load("res://asserts/audio/bg1.wav")
	bgm.volume_db = 0.0
	bgm.play()
	_panel_nodes = [_panel_dim, _panel_bg, _panel_border, _panel_name_lbl,
					_panel_sep, _panel_info_lbl, _upgrade_bg, _upgrade_lbl, _close_bg, _close_lbl]
	call_deferred("_setup")

func _setup() -> void:
	var vp := get_viewport_rect().size
	var bg := Sprite2D.new()
	bg.texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	var tex := bg.texture
	var bg_scale: float = max(vp.x / float(tex.get_width()), vp.y / float(tex.get_height()))
	bg.scale = Vector2(bg_scale, bg_scale)
	bg.position = vp / 2.0
	bg.z_index = -10
	add_child(bg)
	_place_buildings()
	_refresh_hud()

func _input(event: InputEvent) -> void:
	if not bgm.playing:
		bgm.play()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _process(delta: float) -> void:
	_produce_timer += delta
	if _produce_timer >= PRODUCE_INTERVAL:
		_produce_timer = 0.0
		_tick_production()

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
		var ls := LabelSettings.new()
		ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		ls.font_size = 20
		ls.font_color = Color.WHITE
		ls.outline_size = 4
		ls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
		label.label_settings = ls
		container.add_child(label)
		label.size = Vector2(180, 28)
		label.position = Vector2(-90.0, -(sprite.texture.get_height() * BUILDING_SCALE * 0.35) - 8.0 + cfg["y_adj"])

		_building_nodes[key] = {"level": 1, "sprite": sprite, "label": label}
		_refresh_label(key)

func _set_panel_visible(v: bool) -> void:
	var a := 1.0 if v else 0.0
	for node in _panel_nodes:
		node.modulate.a = a
	_panel_visible = v

func _handle_click(pos: Vector2) -> void:
	if _panel_visible:
		if UPGRADE_RECT.has_point(pos) and not _upgrade_disabled:
			_on_upgrade_pressed()
			return
		if CLOSE_RECT.has_point(pos):
			_set_panel_visible(false)
			_panel_key = ""
			return
		if PANEL_RECT.has_point(pos):
			return
		_set_panel_visible(false)
		_panel_key = ""
		return
	for key in _building_nodes:
		if pos.distance_to(BUILDINGS[key]["pos"]) < 80.0:
			_panel_key = key
			_refresh_panel()
			_set_panel_visible(true)
			return

func _refresh_panel() -> void:
	if _panel_key == "":
		return
	var state = _building_nodes[_panel_key]
	var cfg = BUILDINGS[_panel_key]
	var lv: int = state["level"]
	_panel_name_lbl.text = cfg["display"]
	if lv >= 3:
		_panel_info_lbl.text = "等级：%d / 3\n\n已达最高等级" % lv
		_upgrade_disabled = true
		_upgrade_bg.color = Color(0.3, 0.3, 0.3)
	else:
		var cost = cfg["upgrade_cost"][lv - 1]
		var home_lv: int = _building_nodes["home"]["level"]
		if _panel_key != "home" and lv >= home_lv:
			_panel_info_lbl.text = "等级：%d / 3\n\n需先升级主基地至 Lv.%d" % [lv, lv + 1]
			_upgrade_disabled = true
			_upgrade_bg.color = Color(0.3, 0.3, 0.3)
		else:
			var ok: bool = _wood >= int(cost["wood"]) and _ore >= int(cost["ore"])
			_panel_info_lbl.text = "等级：%d / 3\n\n升级消耗：木材 %d   矿石 %d" % [lv, int(cost["wood"]), int(cost["ore"])]
			_upgrade_disabled = not ok
			_upgrade_bg.color = Color(0.18, 0.48, 0.12) if ok else Color(0.3, 0.3, 0.3)

func _on_upgrade_pressed() -> void:
	if _panel_key == "" or _upgrade_disabled:
		return
	var state = _building_nodes[_panel_key]
	var lv: int = state["level"]
	if lv >= 3:
		return
	if _panel_key != "home" and lv >= _building_nodes["home"]["level"]:
		return
	var cost = BUILDINGS[_panel_key]["upgrade_cost"][lv - 1]
	if _wood < int(cost["wood"]) or _ore < int(cost["ore"]):
		return
	_wood -= int(cost["wood"])
	_ore -= int(cost["ore"])
	upgrade_building(_panel_key)
	_refresh_hud()
	_refresh_panel()

func upgrade_building(key: String) -> void:
	if not _building_nodes.has(key):
		return
	var state = _building_nodes[key]
	if state["level"] >= 3:
		return
	state["level"] += 1
	state["sprite"].texture = load(BUILDINGS[key]["paths"][state["level"] - 1])
	_refresh_label(key)

func _tick_production() -> void:
	for key in ["lumberyard", "mine"]:
		if not _building_nodes.has(key):
			continue
		var lv: int = _building_nodes[key]["level"]
		var amount: int = PRODUCE_RATES[lv - 1]
		if BUILDINGS[key]["produces"] == "wood":
			_wood += amount
		else:
			_ore += amount
	_refresh_hud()

func _refresh_hud() -> void:
	if _wood_lbl:
		_wood_lbl.text = "木材  %d" % _wood
	if _ore_lbl:
		_ore_lbl.text = "矿石  %d" % _ore

func _refresh_label(key: String) -> void:
	var state = _building_nodes[key]
	state["label"].text = "%s  Lv.%d" % [BUILDINGS[key]["display"], state["level"]]

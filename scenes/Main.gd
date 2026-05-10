extends Node2D

@onready var bgm: AudioStreamPlayer = $BGM
@onready var _wood_lbl: Label = $UI/WoodLbl
@onready var _ore_lbl: Label = $UI/OreLbl
@onready var _gold_lbl: Label = $UI/GoldLbl
@onready var _panel_dim: ColorRect = $UI/PanelDim
@onready var _panel_bg: TextureRect = $UI/PanelBg
@onready var _panel_name_lbl: Label = $UI/PanelNameLbl
@onready var _panel_info_lbl: Label = $UI/PanelInfoLbl
@onready var _upgrade_btn: TextureRect = $UI/UpgradeBtn
@onready var _upgrade_lbl: Label = $UI/UpgradeLbl
@onready var _close_btn: TextureRect = $UI/CloseBtn

const BUILDING_SCALE := 0.8
const SQUIRREL_OBSTACLES := [[130.0, 410.0], [870.0, 1210.0]]
const PRODUCE_INTERVAL := 5.0
const PRODUCE_RATES := [3, 6, 12]
const SAVE_PATH := "user://savegame.json"

const EXPEDITION_SLOT_POSITIONS := [
	Vector2(460, 240),
	Vector2(550, 240),
	Vector2(640, 240),
	Vector2(730, 240),
	Vector2(820, 240),
]
# 按队伍人数把成员映射到 0-indexed 的站位坐标。
# 中心是 index=2（3 号位），人数不足时从中心向两侧（左侧优先）填充。
const EXPEDITION_LAYOUT_BY_SIZE := {
	1: [2],
	2: [1, 2],
	3: [1, 2, 3],
	4: [0, 1, 2, 3],
	5: [0, 1, 2, 3, 4],
}
const ROLE_IDLE_FRAMES := 12
const ROLE_IDLE_SCALE := 0.085
const EXPEDITION_TEAM := [
	{"name": "圣盾骑士", "idle_sheet": "res://asserts/image/role/role1_idle_sheet.png"},
]

var _panel_rect    := Rect2(440, 200, 400, 380)
var _upgrade_rect  := Rect2(490, 465, 300, 110)
var _close_rect    := Rect2(775, 200, 60, 60)
var _reset_rect    := Rect2(0, 0, 160, 36)

const BUILDINGS := {
	"home": {
		"paths": ["res://asserts/image/building/building_template/home1.png", "res://asserts/image/building/building_template/home2.png", "res://asserts/image/building/building_template/home3.png"],
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/home1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/home2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/home3_anim_sheet.png"], "n_frames": 8, "animated": true,
		"pos": Vector2(640, 375), "display": "主基地", "y_adj": 25,
		"upgrade_cost": [{"wood": 10, "ore": 10}, {"wood": 20, "ore": 20}],
		"produces": "",
		"desc": "村庄的核心，限制其他建筑可达的最高等级。"
	},
	"tower": {
		"paths": ["res://asserts/image/building/building_template/tower1.png", "res://asserts/image/building/building_template/tower2.png", "res://asserts/image/building/building_template/tower3.png"],
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/tower1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tower2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tower3_anim_sheet.png"], "n_frames": 8, "animated": true,
		"pos": Vector2(640, 150), "display": "远征塔", "y_adj": 0,
		"upgrade_cost": [{"wood": 10, "ore": 10}, {"wood": 20, "ore": 20}],
		"produces": "",
		"desc": "远眺地平线，规划下一次远征与探索。"
	},
	"lumberyard": {
		"paths": ["res://asserts/image/building/building_template/lumberyard1.png", "res://asserts/image/building/building_template/lumberyard2.png", "res://asserts/image/building/building_template/lumberyard3.png"],
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/lumberyard1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/lumberyard2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/lumberyard3_anim_sheet.png"], "n_frames": 8, "animated": true,
		"pos": Vector2(210, 275), "display": "伐木场", "y_adj": 25,
		"upgrade_cost": [{"wood": 10, "ore": 10}, {"wood": 20, "ore": 20}],
		"produces": "wood",
		"desc": "持续产出木材，等级越高产能越强。"
	},
	"mine": {
		"paths": ["res://asserts/image/building/building_template/Mine1.png", "res://asserts/image/building/building_template/Mine2.png", "res://asserts/image/building/building_template/Mine3.png"],
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/mine1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/mine2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/mine3_anim_sheet.png"], "n_frames": 8, "animated": true,
		"pos": Vector2(1070, 275), "display": "矿石场", "y_adj": 0,
		"upgrade_cost": [{"wood": 10, "ore": 10}, {"wood": 20, "ore": 20}],
		"produces": "ore",
		"desc": "持续开采矿石，等级越高产能越强。"
	},
	"tavern": {
		"paths": ["res://asserts/image/building/building_template/Tavern1.png", "res://asserts/image/building/building_template/Tavern2.png", "res://asserts/image/building/building_template/Tavern3.png"],
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/tavern1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tavern2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tavern3_anim_sheet.png"], "n_frames": 8, "animated": true,
		"pos": Vector2(270, 510), "display": "酒馆", "y_adj": 0,
		"upgrade_cost": [{"wood": 10, "ore": 10}, {"wood": 20, "ore": 20}],
		"produces": "",
		"desc": "招募旅途中遇见的英雄与冒险者。"
	},
	"research": {
		"paths": ["res://asserts/image/building/building_template/research1.png", "res://asserts/image/building/building_template/research2.png", "res://asserts/image/building/building_template/research3.png"],
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/research1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/research2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/research3_anim_sheet.png"], "n_frames": 8, "animated": true,
		"pos": Vector2(1010, 510), "display": "研究院", "y_adj": 0,
		"upgrade_cost": [{"wood": 10, "ore": 10}, {"wood": 20, "ore": 20}],
		"produces": "",
		"desc": "钻研未知，解锁更强力的科技。"
	},
}

var _wood: int = 200
var _ore: int = 100
var _gold: int = 0
var _reset_bg: ColorRect = null
var _reset_lbl: Label = null
var _panel_movable: Array = []
var _panel_offsets: Array[Vector2] = []
var _building_nodes: Dictionary = {}
var _produce_timer: float = 0.0
var _panel_key: String = ""
var _panel_visible: bool = false
var _panel_nodes: Array = []
var _upgrade_disabled: bool = false
var _bird_frames: SpriteFrames = null
var _squirrel_frames: SpriteFrames = null
var _bird_next_pattern: Array[int] = [0, 1, 2]
var _upgrade_fx_frames: SpriteFrames = null
var _upgrade_fx_scale: float = 1.0

func _ready() -> void:
	bgm.stream = load("res://asserts/audio/bg1.wav")
	bgm.volume_db = 0.0
	bgm.play()
	_panel_nodes = [_panel_dim, _panel_bg, _panel_name_lbl,
					_panel_info_lbl, _upgrade_btn, _upgrade_lbl, _close_btn]
	call_deferred("_setup")

func _setup() -> void:
	var vp := get_viewport_rect().size
	var half_vp := vp / 2.0
	_panel_movable = [_panel_bg, _panel_name_lbl,
					  _panel_info_lbl, _upgrade_btn, _upgrade_lbl, _close_btn]
	var base := _panel_rect.position
	for node in _panel_movable:
		_panel_offsets.append((node as Control).position - base)

	# 背景：稍微放大留出漂移空间
	var bg := Sprite2D.new()
	bg.texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	var tex := bg.texture
	var bg_base: float = max(vp.x / float(tex.get_width()), vp.y / float(tex.get_height()))
	bg.scale = Vector2(bg_base, bg_base)
	bg.position = half_vp
	bg.z_index = -10
	add_child(bg)

# 大气粒子：金色尘埃/花粉缓慢上漂
	var dust := CPUParticles2D.new()
	dust.position = half_vp
	dust.emitting = true
	dust.amount = 40
	dust.lifetime = 6.0
	dust.one_shot = false
	dust.randomness = 1.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(vp.x * 0.52, vp.y * 0.52)
	dust.direction = Vector2(0.2, -1)
	dust.spread = 25.0
	dust.gravity = Vector2(0, -6)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 20.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 4.5
	var dust_grad := Gradient.new()
	dust_grad.set_color(0, Color(1.0, 0.88, 0.5, 0.5))
	dust_grad.set_color(1, Color(1.0, 0.95, 0.7, 0.0))
	dust.color_ramp = dust_grad
	dust.z_index = -2
	add_child(dust)

	_place_buildings()
	_place_expedition_team()
	_load_game()
	_refresh_hud()
	_build_upgrade_fx_frames()
	_build_animal_frames()
	_spawn_bird(0)
	get_tree().create_timer(6.0).timeout.connect(_spawn_bird.bind(1))
	get_tree().create_timer(13.0).timeout.connect(_spawn_bird.bind(2))
	_spawn_squirrel(500.0, 0.73)
	_spawn_squirrel(760.0, 0.77)
	_spawn_squirrel(820.0, 0.20)
	_spawn_reset_button()

func _spawn_reset_button() -> void:
	var ui := $UI
	var vp := get_viewport_rect().size
	_reset_rect = Rect2(vp.x - 170, 10, 160, 36)
	_reset_bg = ColorRect.new()
	_reset_bg.color = Color(0.55, 0.12, 0.10)
	_reset_bg.size = _reset_rect.size
	_reset_bg.position = _reset_rect.position
	ui.add_child(_reset_bg)
	_reset_lbl = Label.new()
	_reset_lbl.text = "重置游戏数据"
	_reset_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reset_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reset_lbl.size = _reset_rect.size
	_reset_lbl.position = _reset_rect.position
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size = 17
	ls.font_color = Color.WHITE
	ls.outline_size = 2
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	_reset_lbl.label_settings = ls
	ui.add_child(_reset_lbl)

func _reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_wood = 200
	_ore = 100
	_gold = 0
	for key in _building_nodes:
		_building_nodes[key]["level"] = 1
		if BUILDINGS[key]["animated"]:
			_apply_anim_sheet(key, 1)
		else:
			(_building_nodes[key]["sprite"] as Sprite2D).texture = load(BUILDINGS[key]["paths"][0])
		_refresh_label(key)
	_refresh_hud()
	_set_panel_visible(false)
	_panel_key = ""

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
		container.z_index = int(cfg["pos"].y)
		add_child(container)

		var display_node: Node2D
		var label_y_offset: float
		if cfg["animated"]:
			var sheet_tex: Texture2D = load(cfg["anim_sheets"][0])
			var n_frames: int = cfg["n_frames"]
			var frame_w := sheet_tex.get_width() / n_frames
			var frame_h := sheet_tex.get_height()
			var orig_tex: Texture2D = load(cfg["paths"][0])
			var scale_by_w := (orig_tex.get_width()  * BUILDING_SCALE) / float(frame_w)
			var scale_by_h := (orig_tex.get_height() * BUILDING_SCALE) / float(frame_h)
			var anim_scale  := minf(scale_by_w, scale_by_h)
			var sf := SpriteFrames.new()
			sf.add_animation("idle")
			sf.set_animation_speed("idle", 8.0)
			sf.set_animation_loop("idle", true)
			for i in n_frames:
				var at := AtlasTexture.new()
				at.atlas = sheet_tex
				at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
				at.filter_clip = true
				sf.add_frame("idle", at)
			var anim_sprite := AnimatedSprite2D.new()
			anim_sprite.sprite_frames = sf
			anim_sprite.scale = Vector2(anim_scale, anim_scale)
			anim_sprite.play("idle")
			display_node = anim_sprite
			label_y_offset = -(frame_h * anim_scale * 0.35) - 8.0 + cfg["y_adj"]
		else:
			var sprite := Sprite2D.new()
			sprite.texture = load(cfg["paths"][0])
			sprite.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
			display_node = sprite
			label_y_offset = -(sprite.texture.get_height() * BUILDING_SCALE * 0.35) - 8.0 + cfg["y_adj"]
		container.add_child(display_node)

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
		label.position = Vector2(-90.0, label_y_offset)

		_building_nodes[key] = {"level": 1, "sprite": display_node, "label": label}
		_refresh_label(key)

func _place_expedition_team() -> void:
	var team_size: int = EXPEDITION_TEAM.size()
	if team_size <= 0:
		return
	var layout: Array = EXPEDITION_LAYOUT_BY_SIZE.get(team_size, [])
	for i in team_size:
		var data = EXPEDITION_TEAM[i]
		if data == null:
			continue
		var slot_index: int = layout[i]
		var pos: Vector2 = EXPEDITION_SLOT_POSITIONS[slot_index]
		var slot := Node2D.new()
		slot.name = "ExpeditionRole%d" % (i + 1)
		slot.position = pos
		slot.z_index = int(pos.y)
		add_child(slot)

		var sheet_tex: Texture2D = load(data["idle_sheet"])
		var frame_w := sheet_tex.get_width() / ROLE_IDLE_FRAMES
		var frame_h := sheet_tex.get_height()
		var sf := SpriteFrames.new()
		sf.add_animation("idle")
		sf.set_animation_speed("idle", 12.0)
		sf.set_animation_loop("idle", true)
		for f in ROLE_IDLE_FRAMES:
			var at := AtlasTexture.new()
			at.atlas = sheet_tex
			at.region = Rect2(f * frame_w, 0, frame_w, frame_h)
			at.filter_clip = true
			sf.add_frame("idle", at)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sf
		sprite.scale = Vector2(ROLE_IDLE_SCALE, ROLE_IDLE_SCALE)
		sprite.play("idle")
		slot.add_child(sprite)

		var name_lbl := Label.new()
		name_lbl.text = data["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(120, 22)
		name_lbl.position = Vector2(-60.0, -frame_h * ROLE_IDLE_SCALE * 0.5 - 24.0)
		var nls := LabelSettings.new()
		nls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		nls.font_size = 14
		nls.font_color = Color(1.0, 0.92, 0.6)
		nls.outline_size = 3
		nls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
		name_lbl.label_settings = nls
		slot.add_child(name_lbl)

func _set_panel_visible(v: bool) -> void:
	var a := 1.0 if v else 0.0
	for node in _panel_nodes:
		node.modulate.a = a
	_panel_visible = v

func _handle_click(pos: Vector2) -> void:
	if _reset_rect.has_point(pos):
		_reset_game()
		return
	if _panel_visible:
		if _upgrade_rect.has_point(pos) and not _upgrade_disabled:
			_on_upgrade_pressed()
			return
		if _close_rect.has_point(pos):
			_set_panel_visible(false)
			_panel_key = ""
			return
		if _panel_rect.has_point(pos):
			return
		_set_panel_visible(false)
		_panel_key = ""
		return
	for key in _building_nodes:
		if pos.distance_to(BUILDINGS[key]["pos"]) < 80.0:
			_panel_key = key
			_refresh_panel()
			_reposition_panel(key)
			_set_panel_visible(true)
			return

func _reposition_panel(key: String) -> void:
	var vp   := get_viewport_rect().size
	var bpos: Vector2 = BUILDINGS[key]["pos"]
	var pw   := _panel_rect.size.x
	var ph   := _panel_rect.size.y
	var gap  := 80.0
	var px   := bpos.x + gap
	if px + pw > vp.x - 10.0:
		px = bpos.x - gap - pw
	px = clampf(px, 10.0, vp.x - pw - 10.0)
	var py := clampf(bpos.y - ph * 0.5, 10.0, vp.y - ph - 10.0)
	var tl := Vector2(px, py)
	_panel_rect    = Rect2(tl, Vector2(pw, ph))
	_upgrade_rect  = Rect2(tl + Vector2(50, 265), Vector2(300, 110))
	_close_rect    = Rect2(tl + Vector2(335, 0), Vector2(60, 60))
	for i in _panel_movable.size():
		(_panel_movable[i] as Control).position = tl + _panel_offsets[i]

func _refresh_panel() -> void:
	if _panel_key == "":
		return
	var state = _building_nodes[_panel_key]
	var cfg = BUILDINGS[_panel_key]
	var lv: int = state["level"]
	_panel_name_lbl.text = "%s  Lv.%d" % [cfg["display"], lv]
	var desc: String = cfg.get("desc", "")
	if lv >= 3:
		_panel_info_lbl.text = "%s\n\n已达最高等级" % desc
		_upgrade_disabled = true
	else:
		var cost = cfg["upgrade_cost"][lv - 1]
		var home_lv: int = _building_nodes["home"]["level"]
		if _panel_key != "home" and lv >= home_lv:
			_panel_info_lbl.text = "%s\n\n需先升级主基地至 Lv.%d" % [desc, lv + 1]
			_upgrade_disabled = true
		else:
			var ok: bool = _wood >= int(cost["wood"]) and _ore >= int(cost["ore"])
			_panel_info_lbl.text = "%s\n\n升级消耗：木材 %d  矿石 %d" % [desc, int(cost["wood"]), int(cost["ore"])]
			_upgrade_disabled = not ok
	var a: float = _upgrade_btn.modulate.a
	var tint: Color = Color(0.55, 0.55, 0.55, a) if _upgrade_disabled else Color(1, 1, 1, a)
	_upgrade_btn.modulate = tint
	_upgrade_lbl.modulate = tint

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
	_save_game()

func upgrade_building(key: String) -> void:
	if not _building_nodes.has(key):
		return
	var state = _building_nodes[key]
	if state["level"] >= 3:
		return
	state["level"] += 1
	var lv: int = state["level"]
	if BUILDINGS[key]["animated"]:
		_apply_anim_sheet(key, lv)
	else:
		(state["sprite"] as Sprite2D).texture = load(BUILDINGS[key]["paths"][lv - 1])
	_refresh_label(key)
	_play_upgrade_fx(BUILDINGS[key]["pos"])

func _apply_anim_sheet(key: String, lv: int) -> void:
	var cfg = BUILDINGS[key]
	var sheet_tex: Texture2D = load(cfg["anim_sheets"][lv - 1])
	var n_frames: int = cfg["n_frames"]
	var frame_w := sheet_tex.get_width() / n_frames
	var frame_h := sheet_tex.get_height()
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 8.0)
	sf.set_animation_loop("idle", true)
	for i in n_frames:
		var at := AtlasTexture.new()
		at.atlas = sheet_tex
		at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		at.filter_clip = true
		sf.add_frame("idle", at)
	var anim_sprite := _building_nodes[key]["sprite"] as AnimatedSprite2D
	var orig_tex: Texture2D = load(cfg["paths"][0])
	var scale_by_w := (orig_tex.get_width()  * BUILDING_SCALE) / float(frame_w)
	var scale_by_h := (orig_tex.get_height() * BUILDING_SCALE) / float(frame_h)
	anim_sprite.sprite_frames = sf
	anim_sprite.scale = Vector2(minf(scale_by_w, scale_by_h), minf(scale_by_w, scale_by_h))
	anim_sprite.play("idle")

func _tick_production() -> void:
	for key in ["lumberyard", "mine"]:
		if not _building_nodes.has(key):
			continue
		var lv: int = _building_nodes[key]["level"]
		var amount: int = PRODUCE_RATES[lv - 1]
		if BUILDINGS[key]["produces"] == "wood":
			_wood += amount
			_spawn_float_text(key, amount, "wood")
		else:
			_ore += amount
			_spawn_float_text(key, amount, "ore")
	_refresh_hud()
	_save_game()

func _spawn_float_text(key: String, amount: int, resource_type: String) -> void:
	var pos: Vector2 = BUILDINGS[key]["pos"]
	var container := Node2D.new()
	container.position = pos
	container.z_index = 900
	add_child(container)
	var lbl := Label.new()
	lbl.text = "+%d" % amount
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(80, 30)
	lbl.position = Vector2(-40.0, -15.0)
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size = 24
	ls.font_color = Color(1.0, 0.88, 0.3) if resource_type == "wood" else Color(0.55, 0.85, 1.0)
	ls.outline_size = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	lbl.label_settings = ls
	container.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(container, "position:y", pos.y - 35.0, 1.0)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.35).set_delay(0.65)
	tween.tween_callback(container.queue_free)

func _refresh_hud() -> void:
	if _wood_lbl:
		_wood_lbl.text = "%d" % _wood
	if _ore_lbl:
		_ore_lbl.text = "%d" % _ore
	if _gold_lbl:
		_gold_lbl.text = "%d" % _gold

func _refresh_label(key: String) -> void:
	var state = _building_nodes[key]
	state["label"].text = "%s  Lv.%d" % [BUILDINGS[key]["display"], state["level"]]

func _save_game() -> void:
	var data := {"wood": _wood, "ore": _ore, "gold": _gold, "levels": {}}
	for key in _building_nodes:
		data["levels"][key] = _building_nodes[key]["level"]
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	if data.has("wood"):
		_wood = int(data["wood"])
	if data.has("ore"):
		_ore = int(data["ore"])
	if data.has("gold"):
		_gold = int(data["gold"])
	if data.has("levels") and data["levels"] is Dictionary:
		var levels: Dictionary = data["levels"]
		for key in levels:
			if not _building_nodes.has(key):
				continue
			var lv: int = clampi(int(levels[key]), 1, 3)
			_building_nodes[key]["level"] = lv
			if BUILDINGS[key]["animated"]:
				_apply_anim_sheet(key, lv)
			else:
				(_building_nodes[key]["sprite"] as Sprite2D).texture = load(BUILDINGS[key]["paths"][lv - 1])
			_refresh_label(key)

func _build_upgrade_fx_frames() -> void:
	var res_path := "res://asserts/fx/building_anim_sheet/build_lv_up_anim_sheet.png"
	var tex: Texture2D = load(res_path)
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
		if img == null:
			push_error("Upgrade FX: cannot load " + res_path)
			return
		tex = ImageTexture.create_from_image(img)
	var cols := 6
	var rows := 2
	var fw := tex.get_width() / cols
	var fh := tex.get_height() / rows
	_upgrade_fx_frames = SpriteFrames.new()
	_upgrade_fx_frames.add_animation("play")
	_upgrade_fx_frames.set_animation_speed("play", 10.0)
	_upgrade_fx_frames.set_animation_loop("play", false)
	for r in rows:
		for c in cols:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(c * fw, r * fh, fw, fh)
			at.filter_clip = true
			_upgrade_fx_frames.add_frame("play", at)
	_upgrade_fx_scale = 200.0 / float(fw)

func _play_upgrade_fx(pos: Vector2) -> void:
	if _upgrade_fx_frames == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = _upgrade_fx_frames
	fx.position = pos
	fx.z_index = 1000
	fx.scale = Vector2(_upgrade_fx_scale, _upgrade_fx_scale)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	add_child(fx)
	fx.animation_finished.connect(fx.queue_free)
	fx.play("play")

func _build_animal_frames() -> void:
	_bird_frames = SpriteFrames.new()
	_bird_frames.add_animation("fly")
	_bird_frames.set_animation_speed("fly", 10.0)
	_bird_frames.set_animation_loop("fly", true)
	var bird_tex: Texture2D = load("res://asserts/image/animal/bird_sheet.png")
	var bw: int = bird_tex.get_width() / 6
	var bh: int = bird_tex.get_height()
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = bird_tex
		at.region = Rect2(i * bw, 0, bw, bh)
		at.filter_clip = true
		_bird_frames.add_frame("fly", at)

	_squirrel_frames = SpriteFrames.new()
	_squirrel_frames.add_animation("run")
	_squirrel_frames.set_animation_speed("run", 10.0)
	_squirrel_frames.set_animation_loop("run", true)
	var sq_tex: Texture2D = load("res://asserts/image/animal/squirrel_sheet.png")
	var sw: int = sq_tex.get_width() / 6
	var sh: int = sq_tex.get_height()
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = sq_tex
		at.region = Rect2(i * sw, 0, sw, sh)
		at.filter_clip = true
		_squirrel_frames.add_frame("run", at)

func _spawn_bird(chain_id: int = 0) -> void:
	var vp := get_viewport_rect().size
	var bird := AnimatedSprite2D.new()
	bird.sprite_frames = _bird_frames
	bird.z_index = 2
	bird.play("fly")
	add_child(bird)

	var go_right: bool = randf() > 0.5
	var start_x: float = -120.0 if go_right else vp.x + 120.0
	var end_x: float   = vp.x + 120.0 if go_right else -120.0
	bird.flip_h = not go_right

	var pattern: int = _bird_next_pattern[chain_id]
	_bird_next_pattern[chain_id] = (pattern + 1 + randi() % 3) % 4

	# 三条链各自占一段高度区间，避免总在同一高度
	var y_min: float = 55.0 + chain_id * 35.0
	var y_max: float = 110.0 + chain_id * 35.0
	var y: float
	var duration: float

	match pattern:
		0:  # 平稳滑翔
			y = randf_range(y_min, y_max)
			duration = randf_range(28.0, 36.0)
			bird.scale = Vector2(0.0675, 0.0675)
			bird.speed_scale = 0.7
			bird.position = Vector2(start_x, y)
			var drift_y := y + randf_range(-15.0, 15.0)
			var t0 := create_tween()
			t0.tween_method(func(p: float):
				if not is_instance_valid(bird): return
				bird.position.x = lerp(start_x, end_x, p)
				bird.position.y = lerp(y, drift_y, p)
			, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t0.tween_callback(bird.queue_free)

		1:  # 正弦波振荡
			y = randf_range(y_min, y_max)
			duration = randf_range(20.0, 28.0)
			bird.scale = Vector2(0.0675, 0.0675)
			bird.speed_scale = 1.0
			bird.position = Vector2(start_x, y)
			var freq := randf_range(2.0, 3.5)
			var amp  := randf_range(10.0, 20.0)
			var t1 := create_tween()
			t1.tween_method(func(p: float):
				if not is_instance_valid(bird): return
				bird.position.x = lerp(start_x, end_x, p)
				bird.position.y = y + sin(p * TAU * freq) * amp
			, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
			t1.tween_callback(bird.queue_free)

		2:  # 抛物线弧
			y = randf_range(y_max - 10.0, y_max + 30.0)
			duration = randf_range(24.0, 32.0)
			bird.scale = Vector2(0.0675, 0.0675)
			bird.speed_scale = 1.0
			bird.position = Vector2(start_x, y)
			var peak_y := y - randf_range(40.0, 70.0)
			var t2 := create_tween()
			t2.tween_method(func(p: float):
				if not is_instance_valid(bird): return
				bird.position.x = lerp(start_x, end_x, p)
				bird.position.y = (1-p)*(1-p)*y + 2*(1-p)*p*peak_y + p*p*y
			, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
			t2.tween_callback(bird.queue_free)

		3:  # 急速冲过
			y = randf_range(y_min, y_max)
			duration = randf_range(10.0, 14.0)
			bird.scale = Vector2(0.05625, 0.05625)
			bird.speed_scale = 1.6
			bird.position = Vector2(start_x, y)
			var t3 := create_tween()
			t3.tween_property(bird, "position:x", end_x, duration)\
				.set_trans(Tween.TRANS_LINEAR)
			t3.tween_callback(bird.queue_free)

	var next := get_tree().create_timer(duration + randf_range(5.0, 14.0))
	next.timeout.connect(_spawn_bird.bind(chain_id))

func _spawn_squirrel(start_x: float, ground_y_frac: float) -> void:
	var vp := get_viewport_rect().size
	var sq := AnimatedSprite2D.new()
	sq.sprite_frames = _squirrel_frames
	var ground_y := vp.y * ground_y_frac
	sq.z_index = int(ground_y)

	var gait := randi() % 4
	sq.set_meta("gait", gait)
	match gait:
		0:
			sq.scale = Vector2(0.06, 0.06)
			sq.speed_scale = 1.0
		1:
			sq.scale = Vector2(0.06, 0.06)
			sq.speed_scale = 0.95
		2:
			sq.scale = Vector2(0.05625, 0.05625)
			sq.speed_scale = 0.7
		3:
			sq.scale = Vector2(0.06, 0.06)
			sq.speed_scale = 0.9

	sq.position = Vector2(start_x, ground_y)
	sq.play("run")
	add_child(sq)
	_squirrel_wander(sq, ground_y)

func _squirrel_clamp_target(from_x: float, to_x: float) -> float:
	var going_right := to_x > from_x
	for obs in SQUIRREL_OBSTACLES:
		var ol: float = obs[0]
		var or_: float = obs[1]
		if going_right and from_x < ol and to_x > ol:
			return ol - 6.0
		if not going_right and from_x > or_ and to_x < or_:
			return or_ + 6.0
	return to_x

func _squirrel_wander(sq: AnimatedSprite2D, ground_y: float) -> void:
	if not is_instance_valid(sq):
		return

	var vp := get_viewport_rect().size
	var gait: int = sq.get_meta("gait", 0)
	var speed: float
	var bounce_amp: float
	var hop_count: int
	var pause_min: float
	var pause_max: float
	match gait:
		0:
			speed = 45.0
			bounce_amp = 6.0
			hop_count = 3
			pause_min = 0.8
			pause_max = 2.5
		1:
			speed = 38.0
			bounce_amp = 8.0
			hop_count = 3
			pause_min = 0.6
			pause_max = 2.0
		2:
			speed = 25.0
			bounce_amp = 4.0
			hop_count = 2
			pause_min = 1.5
			pause_max = 4.0
		3:
			speed = 32.5
			bounce_amp = 20.0
			hop_count = 2
			pause_min = 0.5
			pause_max = 1.8
		_:
			speed = 45.0
			bounce_amp = 6.0
			hop_count = 3
			pause_min = 0.8
			pause_max = 2.5

	var min_y := vp.y * 0.30
	var max_y := vp.y * 0.92
	var start_x := sq.position.x
	var raw_tx := randf_range(0.0, vp.x)
	var target_x := _squirrel_clamp_target(start_x, raw_tx)
	var target_y := clampf(ground_y + randf_range(-80.0, 80.0), min_y, max_y)
	var dist := Vector2(target_x - start_x, target_y - ground_y).length()

	if dist < 30.0:
		raw_tx = vp.x * 0.9 if start_x < vp.x * 0.5 else vp.x * 0.1
		target_x = _squirrel_clamp_target(start_x, raw_tx)
		target_y = clampf(ground_y + randf_range(-80.0, 80.0), min_y, max_y)
		dist = Vector2(target_x - start_x, target_y - ground_y).length()

	var max_dist := speed * 5.0
	if dist > max_dist:
		var dir := Vector2(target_x - start_x, target_y - ground_y).normalized()
		target_x = start_x + dir.x * max_dist
		target_y = ground_y + dir.y * max_dist
		dist = max_dist

	if dist < 1.0:
		get_tree().create_timer(randf_range(pause_min, pause_max)).timeout.connect(func() -> void:
			_squirrel_wander(sq, ground_y)
		)
		return

	sq.flip_h = target_x <= start_x
	sq.play("run")

	var t := create_tween()
	t.tween_method(func(p: float) -> void:
		if not is_instance_valid(sq):
			return
		sq.position.x = lerp(start_x, target_x, p)
		var base_y: float = lerp(ground_y, target_y, p)
		sq.position.y = base_y - abs(sin(p * PI * hop_count)) * bounce_amp
		sq.z_index = int(sq.position.y)
	, 0.0, 1.0, dist / speed).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		if not is_instance_valid(sq):
			return
		sq.stop()
		get_tree().create_timer(randf_range(pause_min, pause_max)).timeout.connect(func() -> void:
			_squirrel_wander(sq, target_y)
		)
	)

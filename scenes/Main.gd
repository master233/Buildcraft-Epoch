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
const LEVELS_TABLE_PATH := "res://asserts/table/levels.txt"
const FIRST_LEVEL_ID := 10101

# 远征队伍由 _resolve_team_from_owned() 根据 owned 角色列表推导：
# owned 取自存档，没存档或字段缺失时读 GlobalConfig.default_owned_roles；
# 入队规则：owned.size() <= MAX_EXPEDITION_SIZE 时全部自动入队，超过则取前 N 个。
const MAX_EXPEDITION_SIZE := 5
var _owned_role_ids: Array[String] = []
var _expedition_team_ids: Array[String] = []
const ROLES_TABLE_PATH := "res://asserts/table/roles.txt"
const TEAM_LAYOUT_PATH := "res://asserts/table/team_layout.txt"
const ROLE_LINES_PATH := "res://asserts/table/role_lines.txt"
const BUILDING_BTN_PATHS := {
	"upgrade":    "res://asserts/image/building/building_button/btn_upgrade.png",
	"tower":      "res://asserts/image/building/building_button/btn_tower.png",
	"lumberyard": "res://asserts/image/building/building_button/btn_lumberyard.png",
	"tavern":     "res://asserts/image/building/building_button/btn_tavern.png",
	"home":       "res://asserts/image/building/building_button/btn_home.png",
	"research":   "res://asserts/image/building/building_button/btn_research.png",
	"mine":       "res://asserts/image/building/building_button/btn_mine.png",
}
const BUILDING_BTN_MAP := {"home": "home", "tower": "tower", "lumberyard": "lumberyard", "tavern": "tavern", "research": "research", "mine": "mine"}
const SPEECH_TICK_INTERVAL := 6.0
const SPEECH_DURATION := 3.0

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
var _cleared_level: int = 0
var _level_ids: Array = []
var _reset_bg: Panel = null
var _reset_lbl: Label = null
var _reset_style: StyleBoxFlat = null
var _reset_hovering: bool = false
var _expedition_btn_bg: Panel = null
var _expedition_btn_lbl: Label = null
var _expedition_btn_rect := Rect2(0, 0, 120, 48)

const FORMATION_BTN_W := 130.0
var _formation_id: int = 1
var _formation_name: String = "标准阵"
var _formation_btn_bg: Panel = null
var _formation_btn_lbl: Label = null
var _formation_btn_rect := Rect2(0, 0, FORMATION_BTN_W, 48)
var _panel_movable: Array = []
var _panel_offsets: Array[Vector2] = []
var _building_nodes: Dictionary = {}
var _produce_timer: float = 0.0
var _panel_key: String = ""
var _panel_visible: bool = false
var _panel_nodes: Array = []
var _upgrade_disabled: bool = false
var _upgrade_pressing: bool = false
var _bird_frames: SpriteFrames = null
var _squirrel_frames: SpriteFrames = null
var _bird_next_pattern: Array[int] = [0, 1, 2]
var _upgrade_fx_frames: SpriteFrames = null
var _upgrade_fx_scale: float = 1.0
var _roles: Dictionary = {}  # role_id → {name, idle_sheet, idle_frames, idle_scale, idle_anim_fps}
var _slot_positions: Array[Vector2] = []
var _layout_by_size: Dictionary = {}  # team_size:int → Array[int] of slot indices
var _role_lines: Dictionary = {}
var _team_slots: Array = []  # [{slot: Node2D, role_id: String, head_top_y, name_lbl, stars_lbl}]
var _team_levels: Array[int] = []
var _team_stars: Array[int] = []
var _speech_timer: float = 0.0
var _is_anyone_speaking: bool = false
var _last_speech_slot_idx: int = -1

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
	_load_roles_table()
	_load_team_layout()
	_load_role_lines()
	_resolve_team_from_owned()
	_place_expedition_team()
	_load_level_ids()
	_load_game()
	_refresh_hud()
	_build_animal_frames()
	# 升级特效较大（~95MB GPU），延迟 0.5s 加载，避免阻塞场景首帧渲染
	get_tree().create_timer(0.5).timeout.connect(_build_upgrade_fx_frames)
	_spawn_bird(0)
	get_tree().create_timer(6.0).timeout.connect(_spawn_bird.bind(1))
	get_tree().create_timer(13.0).timeout.connect(_spawn_bird.bind(2))
	_spawn_squirrel(500.0, 0.50)
	_spawn_squirrel(820.0, 0.55)
	_spawn_reset_button()
	_spawn_expedition_button()

	# 从阵型选择场景返回时，读取玩家选中的阵型
	var sel_id = GlobalConfig.get_runtime("selected_formation_id")
	if sel_id != null:
		_formation_id   = int(sel_id)
		_formation_name = String(GlobalConfig.get_runtime("selected_formation_name"))
		GlobalConfig.clear_runtime()
		_refresh_formation_btn()
		_save_game()

func _spawn_reset_button() -> void:
	var ui := $UI
	var vp := get_viewport_rect().size
	_reset_rect = Rect2(vp.x - 178, 12, 164, 42)

	_reset_style = StyleBoxFlat.new()
	_reset_style.bg_color = Color(0.42, 0.07, 0.07)
	_reset_style.set_corner_radius_all(10)
	_reset_style.border_width_top    = 2
	_reset_style.border_width_right  = 2
	_reset_style.border_width_bottom = 3
	_reset_style.border_width_left   = 2
	_reset_style.border_color = Color(0.80, 0.28, 0.22, 1.0)
	_reset_style.shadow_color = Color(0, 0, 0, 0.55)
	_reset_style.shadow_size  = 6
	_reset_style.shadow_offset = Vector2(1, 3)

	_reset_bg = Panel.new()
	_reset_bg.size     = _reset_rect.size
	_reset_bg.position = _reset_rect.position
	_reset_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_bg.add_theme_stylebox_override("panel", _reset_style)
	ui.add_child(_reset_bg)

	_reset_lbl = Label.new()
	_reset_lbl.text = "重置游戏数据"
	_reset_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reset_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_reset_lbl.size     = _reset_rect.size
	_reset_lbl.position = _reset_rect.position
	_reset_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size  = 20
	ls.font_color = Color(1.0, 0.82, 0.82)
	ls.outline_size  = 2
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.75)
	ls.shadow_size   = 2
	ls.shadow_color  = Color(0, 0, 0, 0.45)
	_reset_lbl.label_settings = ls
	ui.add_child(_reset_lbl)

const BATTLE_SCENE_PATH := "res://scenes/BattleScene.tscn"

func _spawn_expedition_button() -> void:
	var ui := $UI
	var vp := get_viewport_rect().size
	var btn_y := 670.0
	var gap := 10.0
	var total_w := _expedition_btn_rect.size.x + gap + FORMATION_BTN_W
	var start_x := vp.x * 0.5 - total_w * 0.5

	# 出征按钮
	_expedition_btn_rect = Rect2(start_x, btn_y, _expedition_btn_rect.size.x, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.32, 0.05, 0.92)
	style.set_corner_radius_all(12)
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 3
	style.border_width_left   = 2
	style.border_color  = Color(1.0, 0.78, 0.25, 1.0)
	style.shadow_color  = Color(0, 0, 0, 0.6)
	style.shadow_size   = 8
	style.shadow_offset = Vector2(1, 3)

	_expedition_btn_bg = Panel.new()
	_expedition_btn_bg.size     = _expedition_btn_rect.size
	_expedition_btn_bg.position = _expedition_btn_rect.position
	_expedition_btn_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expedition_btn_bg.add_theme_stylebox_override("panel", style)
	ui.add_child(_expedition_btn_bg)

	_expedition_btn_lbl = Label.new()
	_expedition_btn_lbl.text = "出征"
	_expedition_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expedition_btn_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_expedition_btn_lbl.size     = _expedition_btn_rect.size
	_expedition_btn_lbl.position = _expedition_btn_rect.position
	_expedition_btn_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	var ls := LabelSettings.new()
	ls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size  = 26
	ls.font_color = Color(1.0, 0.95, 0.6)
	ls.outline_size  = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	ls.shadow_size   = 3
	ls.shadow_color  = Color(0, 0, 0, 0.5)
	_expedition_btn_lbl.label_settings = ls
	ui.add_child(_expedition_btn_lbl)
	_expedition_btn_lbl.gui_input.connect(_on_expedition_btn_input)

	# 阵型按钮（出征按钮右侧）
	var form_x := start_x + _expedition_btn_rect.size.x + gap
	_formation_btn_rect = Rect2(form_x, btn_y, FORMATION_BTN_W, 48)

	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.08, 0.22, 0.45, 0.92)
	fstyle.set_corner_radius_all(12)
	fstyle.border_width_top    = 2
	fstyle.border_width_right  = 2
	fstyle.border_width_bottom = 3
	fstyle.border_width_left   = 2
	fstyle.border_color  = Color(0.35, 0.70, 1.0, 1.0)
	fstyle.shadow_color  = Color(0, 0, 0, 0.6)
	fstyle.shadow_size   = 8
	fstyle.shadow_offset = Vector2(1, 3)

	_formation_btn_bg = Panel.new()
	_formation_btn_bg.size     = _formation_btn_rect.size
	_formation_btn_bg.position = _formation_btn_rect.position
	_formation_btn_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_formation_btn_bg.add_theme_stylebox_override("panel", fstyle)
	ui.add_child(_formation_btn_bg)

	_formation_btn_lbl = Label.new()
	_formation_btn_lbl.text = _formation_name
	_formation_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formation_btn_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_formation_btn_lbl.size     = _formation_btn_rect.size
	_formation_btn_lbl.position = _formation_btn_rect.position
	_formation_btn_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	var fls := LabelSettings.new()
	fls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	fls.font_size  = 22
	fls.font_color = Color(0.75, 0.92, 1.0)
	fls.outline_size  = 3
	fls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	fls.shadow_size   = 3
	fls.shadow_color  = Color(0, 0, 0, 0.5)
	_formation_btn_lbl.label_settings = fls
	ui.add_child(_formation_btn_lbl)
	_formation_btn_lbl.gui_input.connect(_on_formation_btn_input)

func _refresh_formation_btn() -> void:
	if _formation_btn_lbl and is_instance_valid(_formation_btn_lbl):
		_formation_btn_lbl.text = _formation_name

func _on_expedition_btn_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		GlobalConfig.set_runtime("scene_mode", "battle")
		GlobalConfig.set_runtime("formation_id", _formation_id)
		GlobalConfig.set_runtime("level_id", _next_level_id())
		var scene := load(BATTLE_SCENE_PATH) as PackedScene
		SceneTransition.change_to(scene)

func _next_level_id() -> String:
	if _level_ids.is_empty():
		return str(FIRST_LEVEL_ID)
	for lid in _level_ids:
		if int(lid) > _cleared_level:
			return String(lid)
	return String(_level_ids[_level_ids.size() - 1])

func _load_level_ids() -> void:
	_level_ids.clear()
	var file := FileAccess.open(LEVELS_TABLE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 1:
			continue
		var lid_str: String = (parts[0] as String).strip_edges()
		if lid_str.is_valid_int():
			_level_ids.append(lid_str)
	_level_ids.sort_custom(func(a, b): return int(a) < int(b))

func _on_formation_btn_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		GlobalConfig.set_runtime("scene_mode", "formation")
		GlobalConfig.set_runtime("formation_id", _formation_id)
		var scene := load(BATTLE_SCENE_PATH) as PackedScene
		SceneTransition.change_to(scene)

func _reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_wood = 200
	_ore = 100
	_gold = 0
	_cleared_level = 0
	for key in _building_nodes:
		_building_nodes[key]["level"] = 1
		if BUILDINGS[key]["animated"]:
			_apply_anim_sheet(key, 1)
		else:
			(_building_nodes[key]["sprite"] as Sprite2D).texture = load(BUILDINGS[key]["paths"][0])
		_refresh_label(key)
	_clear_team_nodes()
	_resolve_team_from_owned()
	_place_expedition_team()
	_refresh_hud()
	_set_panel_visible(false)
	_panel_key = ""
	_save_game()

func _clear_team_nodes() -> void:
	for entry in _team_slots:
		var node = entry.get("slot", null)
		if node != null and is_instance_valid(node):
			node.queue_free()
	_team_slots.clear()
	_team_levels.clear()
	_team_stars.clear()

func _input(event: InputEvent) -> void:
	if not bgm.playing:
		bgm.play()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _panel_visible and _upgrade_rect.has_point(event.position) and not _upgrade_disabled:
				_upgrade_pressing = true
				_upgrade_btn.pivot_offset = _upgrade_btn.size / 2
				_upgrade_lbl.pivot_offset = _upgrade_lbl.size / 2
				var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(_upgrade_btn, "scale", Vector2(0.78, 0.78), 0.1)
				tw.parallel().tween_property(_upgrade_lbl, "scale", Vector2(0.78, 0.78), 0.1)
			_handle_click(event.position)
		else:
			if _upgrade_pressing:
				_upgrade_pressing = false
				var tw := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
				tw.tween_property(_upgrade_btn, "scale", Vector2(1.0, 1.0), 0.5)
				tw.parallel().tween_property(_upgrade_lbl, "scale", Vector2(1.0, 1.0), 0.5)

func _process(delta: float) -> void:
	_produce_timer += delta
	if _produce_timer >= PRODUCE_INTERVAL:
		_produce_timer = 0.0
		_tick_production()
	_speech_timer += delta
	if _speech_timer >= SPEECH_TICK_INTERVAL:
		_speech_timer = 0.0
		_tick_speech()
	if _reset_style != null:
		var hov := _reset_rect.has_point(get_viewport().get_mouse_position())
		if hov != _reset_hovering:
			_reset_hovering = hov
			_reset_style.bg_color     = Color(0.62, 0.12, 0.12) if hov else Color(0.42, 0.07, 0.07)
			_reset_style.border_color = Color(0.95, 0.40, 0.32) if hov else Color(0.80, 0.28, 0.22)

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

		# 建筑按钮：升级和功能按钮显示在名字上方
		var up_sprite: Sprite2D = null
		var fn_sprite: Sprite2D = null
		var btn_size := 36.0
		var btn_gap := 6.0
		var btn_y := label_y_offset - btn_size - 4.0
		# 升级按钮
		var up_tex: Texture2D = load(BUILDING_BTN_PATHS["upgrade"])
		if up_tex:
			var up_scale := btn_size / up_tex.get_height()
			up_sprite = Sprite2D.new()
			up_sprite.texture = up_tex
			up_sprite.scale = Vector2(up_scale, up_scale)
			up_sprite.set_meta("base_scale", Vector2(up_scale, up_scale))
			up_sprite.position = Vector2(-btn_size * 0.5 - btn_gap * 0.5, btn_y + btn_size * 0.5)
			container.add_child(up_sprite)
		# 功能按钮
		var func_name: String = BUILDING_BTN_MAP.get(key, "")
		if not func_name.is_empty():
			var fn_tex: Texture2D = load(BUILDING_BTN_PATHS[func_name])
			if fn_tex:
				var fn_scale := btn_size / fn_tex.get_height()
				fn_sprite = Sprite2D.new()
				fn_sprite.texture = fn_tex
				fn_sprite.scale = Vector2(fn_scale, fn_scale)
				fn_sprite.position = Vector2(btn_size * 0.5 + btn_gap * 0.5, btn_y + btn_size * 0.5)
				container.add_child(fn_sprite)

		_building_nodes[key] = {"level": 1, "sprite": display_node, "label": label, "upgrade_btn": up_sprite, "func_btn": fn_sprite}
		_refresh_label(key)

func _place_expedition_team() -> void:
	var team_size: int = _expedition_team_ids.size()
	if team_size <= 0 or _slot_positions.is_empty():
		return
	var layout: Array = _layout_by_size.get(team_size, [])
	if layout.is_empty():
		push_warning("team_layout.txt missing layout_size_%d" % team_size)
		return
	# 初始化每个成员的等级/星级，默认值取自 roles.txt 的 init_level / init_star；
	# 后面 _load_game 会用存档覆盖
	_team_levels.clear()
	_team_stars.clear()
	for i in team_size:
		var rid: String = _expedition_team_ids[i]
		var role_data: Dictionary = _roles.get(rid, {})
		_team_levels.append(int(role_data.get("init_level", 1)))
		_team_stars.append(int(role_data.get("init_star", 1)))
	for i in team_size:
		var role_id: String = _expedition_team_ids[i]
		if not _roles.has(role_id):
			push_warning("roles.txt missing role_id: " + role_id)
			continue
		var data: Dictionary = _roles[role_id]
		var idle_frames: int = int(data.get("idle_frames", 1))
		var idle_scale: float = float(data.get("idle_scale", 1.0))
		var idle_anim_fps: float = float(data.get("idle_anim_fps", 8.0))
		var slot_index: int = int(layout[i])
		if slot_index < 0 or slot_index >= _slot_positions.size():
			continue
		var pos: Vector2 = _slot_positions[slot_index]
		var slot := Node2D.new()
		slot.name = "ExpeditionRole%d" % (i + 1)
		slot.position = pos
		slot.z_index = int(pos.y)
		add_child(slot)

		var sheet_tex: Texture2D = load(data["idle_sheet"])
		var frame_w := sheet_tex.get_width() / idle_frames
		var frame_h := sheet_tex.get_height()
		_team_slots.append({
			"slot": slot,
			"role_id": role_id,
			"head_top_y": -frame_h * idle_scale * 0.5,
			"current_action": "idle",  # 当前动作：idle / alert / attack / cast
		})
		var sf := SpriteFrames.new()
		sf.add_animation("idle")
		sf.set_animation_speed("idle", idle_anim_fps)
		sf.set_animation_loop("idle", true)
		for f in idle_frames:
			var at := AtlasTexture.new()
			at.atlas = sheet_tex
			at.region = Rect2(f * frame_w, 0, frame_w, frame_h)
			at.filter_clip = true
			sf.add_frame("idle", at)

		# 构建 alert 动画（如果有）
		var alert_sheet_path: String = String(data.get("alert_sheet", ""))
		if not alert_sheet_path.is_empty() and ResourceLoader.exists(alert_sheet_path):
			var alert_frames: int = int(data.get("alert_frames", 1))
			var alert_anim_fps: float = float(data.get("alert_anim_fps", 12.0))
			var alert_tex: Texture2D = load(alert_sheet_path)
			var alert_w := alert_tex.get_width() / alert_frames
			var alert_h := alert_tex.get_height()
			sf.add_animation("alert")
			sf.set_animation_speed("alert", alert_anim_fps)
			sf.set_animation_loop("alert", true)
			for f in alert_frames:
				var at := AtlasTexture.new()
				at.atlas = alert_tex
				at.region = Rect2(f * alert_w, 0, alert_w, alert_h)
				at.filter_clip = true
				sf.add_frame("alert", at)

		# 构建 attack 动画（如果有）
		var attack_sheet_path: String = String(data.get("attack_sheet", ""))
		if not attack_sheet_path.is_empty() and ResourceLoader.exists(attack_sheet_path):
			var attack_frames: int = int(data.get("attack_frames", 1))
			var attack_anim_fps: float = float(data.get("attack_anim_fps", 12.0))
			var attack_tex: Texture2D = load(attack_sheet_path)
			var attack_w := attack_tex.get_width() / attack_frames
			var attack_h := attack_tex.get_height()
			sf.add_animation("attack")
			sf.set_animation_speed("attack", attack_anim_fps)
			sf.set_animation_loop("attack", true)
			for f in attack_frames:
				var at := AtlasTexture.new()
				at.atlas = attack_tex
				at.region = Rect2(f * attack_w, 0, attack_w, attack_h)
				at.filter_clip = true
				sf.add_frame("attack", at)

		# 构建 dead 动画（如果有）
		var dead_sheet_path: String = String(data.get("dead_sheet", ""))
		if not dead_sheet_path.is_empty() and ResourceLoader.exists(dead_sheet_path):
			var dead_frames: int = int(data.get("dead_frames", 1))
			var dead_anim_fps: float = float(data.get("dead_anim_fps", 12.0))
			var dead_tex: Texture2D = load(dead_sheet_path)
			var dead_w := dead_tex.get_width() / dead_frames
			var dead_h := dead_tex.get_height()
			sf.add_animation("dead")
			sf.set_animation_speed("dead", dead_anim_fps)
			sf.set_animation_loop("dead", false)
			for f in dead_frames:
				var at := AtlasTexture.new()
				at.atlas = dead_tex
				at.region = Rect2(f * dead_w, 0, dead_w, dead_h)
				at.filter_clip = true
				sf.add_frame("dead", at)

		# 构建 cast 动画（如果有）
		var cast_sheet_path: String = String(data.get("cast_sheet", ""))
		if not cast_sheet_path.is_empty() and ResourceLoader.exists(cast_sheet_path):
			var cast_frames: int = int(data.get("cast_frames", 1))
			var cast_anim_fps: float = float(data.get("cast_anim_fps", 12.0))
			var cast_tex: Texture2D = load(cast_sheet_path)
			var cast_w := cast_tex.get_width() / cast_frames
			var cast_h := cast_tex.get_height()
			sf.add_animation("cast")
			sf.set_animation_speed("cast", cast_anim_fps)
			sf.set_animation_loop("cast", true)
			for f in cast_frames:
				var at := AtlasTexture.new()
				at.atlas = cast_tex
				at.region = Rect2(f * cast_w, 0, cast_w, cast_h)
				at.filter_clip = true
				sf.add_frame("cast", at)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sf
		sprite.scale = Vector2(idle_scale, idle_scale)
		sprite.play("idle")
		slot.add_child(sprite)
		_team_slots[_team_slots.size() - 1]["sprite"] = sprite

		# 星级行：放在角色脚下
		var stars_box := HBoxContainer.new()
		stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
		# 负 separation 抵消 PNG 自带的透明 padding，让相邻星视觉上不留空隙
		stars_box.add_theme_constant_override("separation", -6)
		stars_box.size = Vector2(160, 24)
		stars_box.position = Vector2(-80.0, frame_h * idle_scale * 0.4)
		slot.add_child(stars_box)

		# 名字 + 等级：紧贴角色头顶
		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(160, 22)
		name_lbl.position = Vector2(-80.0, -frame_h * idle_scale * 0.5 - 24.0)
		var nls := LabelSettings.new()
		nls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		nls.font_size = 14
		nls.font_color = Color(1.0, 0.92, 0.6)
		nls.outline_size = 3
		nls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
		name_lbl.label_settings = nls
		slot.add_child(name_lbl)
		_team_slots[_team_slots.size() - 1]["name_lbl"] = name_lbl
		_team_slots[_team_slots.size() - 1]["stars_box"] = stars_box
		_refresh_role_label(_team_slots.size() - 1)

const STAR_ICON_PATH := "res://asserts/image/ui/star.png"
const STAR_ICON_SIZE := Vector2(22, 22)

func _refresh_role_label(idx: int) -> void:
	if idx < 0 or idx >= _team_slots.size():
		return
	var entry = _team_slots[idx]
	var role_id: String = entry.get("role_id", "")
	var role_data: Dictionary = _roles.get(role_id, {})
	var role_name: String = String(role_data.get("name", role_id))
	var lv: int = _team_levels[idx] if idx < _team_levels.size() else 1
	var star: int = _team_stars[idx] if idx < _team_stars.size() else 1
	if entry.has("name_lbl") and entry["name_lbl"]:
		entry["name_lbl"].text = "%s  Lv.%d" % [role_name, lv]
	if entry.has("stars_box") and entry["stars_box"]:
		var box: HBoxContainer = entry["stars_box"]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var star_tex: Texture2D = load(STAR_ICON_PATH)
		for n in maxi(star, 0):
			var sr := TextureRect.new()
			sr.texture = star_tex
			sr.custom_minimum_size = STAR_ICON_SIZE
			sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(sr)


func _read_table_text(path: String) -> String:
	# 注意：不能用 FileAccess.file_exists() 预检查 —— Godot 4 在 Web 导出里对 pack 内的
	# 非资源文件（.txt 等）返回 false，导致漏读。直接 open() 用返回值判断。
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[Main] table not found: ", path, " err=", FileAccess.get_open_error())
		return ""
	var text := file.get_as_text()
	file.close()
	# 去除可能的 UTF-8 BOM。不能用字面量 "﻿" 判断 —— 源码里的 BOM 字面量
	# 会被 Godot 导出过程吞掉变成空串，导致 begins_with 永远 true、误砍首字符。
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	return text

func _load_roles_table() -> void:
	var text := _read_table_text(ROLES_TABLE_PATH)
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return
	var headers := (raw[0] as String).strip_edges().split("\t")
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < headers.size():
			continue
		var entry := {}
		for j in headers.size():
			entry[headers[j]] = parts[j]
		var rid: String = String(entry.get("role_id", ""))
		if rid.is_empty():
			continue
		_roles[rid] = {
			"name": String(entry.get("name", "")),
			"idle_sheet": String(entry.get("idle_sheet", "")),
			"idle_frames": int(entry.get("idle_frames", "1")),
			"idle_scale": float(entry.get("idle_scale", "1.0")),
			"idle_anim_fps": float(entry.get("idle_anim_fps", "8.0")),
			"alert_sheet": String(entry.get("alert_sheet", "")),
			"alert_frames": int(entry.get("alert_frames", "1")),
			"alert_anim_fps": float(entry.get("alert_anim_fps", "12.0")),
			"attack_sheet": String(entry.get("attack_sheet", "")),
			"attack_frames": int(entry.get("attack_frames", "1")),
			"attack_anim_fps": float(entry.get("attack_anim_fps", "12.0")),
			"cast_sheet": String(entry.get("cast_sheet", "")),
			"cast_frames": int(entry.get("cast_frames", "1")),
			"cast_anim_fps": float(entry.get("cast_anim_fps", "12.0")),
			"dead_sheet": String(entry.get("dead_sheet", "")),
			"dead_frames": int(entry.get("dead_frames", "1")),
			"dead_anim_fps": float(entry.get("dead_anim_fps", "12.0")),
			"init_level": int(entry.get("init_level", "1")),
			"init_star": int(entry.get("init_star", "1")),
		}

func _resolve_team_from_owned() -> void:
	# 存档存在 → 以存档为准（即使某字段缺失也不回退到配表，避免静默合入默认角色）
	# 存档不存在（首次进入 / 重置后） → 从 GlobalConfig.default_owned_roles 初始化，队伍取前 MAX_EXPEDITION_SIZE 人
	_owned_role_ids.clear()
	_expedition_team_ids.clear()
	if FileAccess.file_exists(SAVE_PATH):
		var save_data := _read_save_dict()
		var owned_arr: Array = save_data.get("owned_roles", []) if save_data.get("owned_roles", null) is Array else []
		var team_arr: Array = save_data.get("team_ids", []) if save_data.get("team_ids", null) is Array else []
		for rid in owned_arr:
			var s: String = String(rid)
			if _roles.has(s) and not s in _owned_role_ids:
				_owned_role_ids.append(s)
		for rid in team_arr:
			var s2: String = String(rid)
			if not _roles.has(s2) or s2 in _expedition_team_ids:
				continue
			if not s2 in _owned_role_ids:
				continue
			if _expedition_team_ids.size() >= MAX_EXPEDITION_SIZE:
				break
			_expedition_team_ids.append(s2)
	else:
		var defaults := GlobalConfig.get_str("default_owned_roles", "")
		for piece in defaults.split(","):
			var rid: String = (piece as String).strip_edges()
			if rid.is_empty() or not _roles.has(rid) or rid in _owned_role_ids:
				continue
			_owned_role_ids.append(rid)
		var cap: int = min(_owned_role_ids.size(), MAX_EXPEDITION_SIZE)
		for i in cap:
			_expedition_team_ids.append(_owned_role_ids[i])

func _read_save_dict() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func _load_team_layout() -> void:
	var text := _read_table_text(TEAM_LAYOUT_PATH)
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return
	var slot_dict := {}
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 2:
			continue
		var key: String = (parts[0] as String).strip_edges()
		var value: String = (parts[1] as String).strip_edges()
		if key.begins_with("slot_"):
			var idx := int(key.substr(5))
			var coords := value.split(",")
			if coords.size() >= 2:
				slot_dict[idx] = Vector2(float(coords[0]), float(coords[1]))
		elif key.begins_with("layout_size_"):
			var size := int(key.substr(12))
			var indices: Array[int] = []
			for s in value.split(","):
				indices.append(int((s as String).strip_edges()))
			_layout_by_size[size] = indices
	var ordered := slot_dict.keys()
	ordered.sort()
	_slot_positions.clear()
	for k in ordered:
		_slot_positions.append(slot_dict[k])

func _load_role_lines() -> void:
	var file := FileAccess.open(ROLE_LINES_PATH, FileAccess.READ)
	if file == null:
		print("[Main] role_lines.txt not found: ", ROLE_LINES_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var raw_lines := text.split("\n", false)
	for i in range(1, raw_lines.size()):  # skip header
		var line: String = (raw_lines[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 3:
			continue
		var role_id: String = parts[1]
		var content: String = parts[2]
		if not _role_lines.has(role_id):
			_role_lines[role_id] = []
		(_role_lines[role_id] as Array).append(content)

func _tick_speech() -> void:
	if _is_anyone_speaking or _team_slots.is_empty():
		return
	var eligible: Array[int] = []
	for i in _team_slots.size():
		var rid: String = _team_slots[i]["role_id"]
		if _role_lines.has(rid) and not (_role_lines[rid] as Array).is_empty():
			eligible.append(i)
	if eligible.is_empty():
		return
	# 不允许与上一次同槽位重复；只有一人可选时才豁免
	var pool: Array[int] = eligible
	if eligible.size() > 1 and _last_speech_slot_idx in eligible:
		pool = eligible.filter(func(i): return i != _last_speech_slot_idx)
	var idx: int = pool[randi() % pool.size()]
	_last_speech_slot_idx = idx
	_show_speech_bubble(idx)

func _show_speech_bubble(slot_idx: int) -> void:
	var entry = _team_slots[slot_idx]
	var slot: Node2D = entry["slot"]
	var role_id: String = entry["role_id"]
	var lines: Array = _role_lines[role_id]
	var content: String = lines[randi() % lines.size()]

	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var font_size := 16
	var max_w := 280.0
	var pad := Vector2(14, 9)
	var text_size := font.get_multiline_string_size(content, HORIZONTAL_ALIGNMENT_CENTER, max_w, font_size)
	var panel_w: float = clampf(text_size.x + pad.x * 2.0, 80.0, max_w + pad.x * 2.0)
	var panel_h: float = text_size.y + pad.y * 2.0

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.91, 0.76, 0.96)
	style.set_corner_radius_all(10)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.42, 0.27, 0.13, 1.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(panel_w, panel_h)
	var head_top_y: float = entry["head_top_y"]
	panel.position = Vector2(-panel_w * 0.5, head_top_y - panel_h - 8.0)

	var lbl := Label.new()
	lbl.text = content
	lbl.position = pad
	lbl.size = Vector2(panel_w - pad.x * 2.0, panel_h - pad.y * 2.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = font_size
	ls.font_color = Color(0.20, 0.13, 0.06)
	lbl.label_settings = ls
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	panel.z_index = 50
	slot.add_child(panel)

	_is_anyone_speaking = true
	var fade_in := 0.18
	var fade_out := 0.18
	var hold := SPEECH_DURATION - fade_in - fade_out
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, fade_in)
	tween.tween_interval(maxf(hold, 0.0))
	tween.tween_property(panel, "modulate:a", 0.0, fade_out)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
		_is_anyone_speaking = false
	)

func _set_panel_visible(v: bool) -> void:
	var a := 1.0 if v else 0.0
	for node in _panel_nodes:
		node.modulate.a = a
	_panel_visible = v

func _handle_click(pos: Vector2) -> void:
	if _reset_rect.has_point(pos):
		_reset_bg.pivot_offset = _reset_bg.size / 2
		_reset_lbl.pivot_offset = _reset_lbl.size / 2
		var tw := create_tween()
		tw.tween_property(_reset_bg,  "scale", Vector2(0.82, 0.82), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_reset_lbl, "scale", Vector2(0.82, 0.82), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_reset_bg,  "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_reset_lbl, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
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

	# 检测角色点击
	for i in _team_slots.size():
		var entry = _team_slots[i]
		var slot: Node2D = entry["slot"]
		if pos.distance_to(slot.position) < 60.0:
			_switch_role_action(i)
			return

		for key in _building_nodes:
			var btn = _building_nodes[key].get("upgrade_btn")
			if btn and is_instance_valid(btn):
				var btn_pos: Vector2 = BUILDINGS[key]["pos"] + btn.position
				if pos.distance_to(btn_pos) < 24.0:
					var is_disabled: bool = btn.get_meta("disabled", false)
					if not is_disabled:
						# 点击动画
						var base_s: Vector2 = btn.get_meta("base_scale", btn.scale)
						var tw := create_tween()
						tw.tween_property(btn, "scale", base_s * 0.75, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						tw.tween_property(btn, "scale", base_s, 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
					# 打开升级面板
					_panel_key = key
					_refresh_panel()
					_reposition_panel(key)
					_set_panel_visible(true)
					return
func _switch_role_action(idx: int) -> void:
	if idx < 0 or idx >= _team_slots.size():
		return
	var entry = _team_slots[idx]
	var sprite: AnimatedSprite2D = entry.get("sprite", null)
	if sprite == null:
		return
	var action_order := ["idle", "alert", "attack", "cast", "dead"]
	var current: String = entry.get("current_action", "idle")
	var current_idx := action_order.find(current)
	if current_idx == -1:
		current_idx = 0
	var next_action := "idle"
	for step in range(1, action_order.size() + 1):
		var candidate: String = action_order[(current_idx + step) % action_order.size()]
		if candidate == "idle" or sprite.sprite_frames.has_animation(candidate):
			next_action = candidate
			break

	entry["current_action"] = next_action
	sprite.play(next_action)

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
	_upgrade_rect  = Rect2(tl + Vector2(50, 250), Vector2(300, 110))
	_close_rect    = Rect2(tl + Vector2(335, 20), Vector2(60, 60))
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
	var produces: String = cfg.get("produces", "")
	var prod_info := ""
	if produces != "":
		var res_name := "木材" if produces == "wood" else "矿石"
		prod_info = "\n当前产量：%d %s / %d 秒" % [PRODUCE_RATES[lv - 1], res_name, int(PRODUCE_INTERVAL)]
		if lv < 3:
			prod_info += "\n下一级产量：%d %s / %d 秒" % [PRODUCE_RATES[lv], res_name, int(PRODUCE_INTERVAL)]
	if lv >= 3:
		_panel_info_lbl.text = "%s%s\n\n已达最高等级" % [desc, prod_info]
		_upgrade_disabled = true
	else:
		var cost = cfg["upgrade_cost"][lv - 1]
		var home_lv: int = _building_nodes["home"]["level"]
		if _panel_key != "home" and lv >= home_lv:
			_panel_info_lbl.text = "%s%s\n\n需先升级主基地至 Lv.%d" % [desc, prod_info, lv + 1]
			_upgrade_disabled = true
		else:
			var ok: bool = _wood >= int(cost["wood"]) and _ore >= int(cost["ore"])
			_panel_info_lbl.text = "%s%s\n\n升级消耗：木材 %d  矿石 %d" % [desc, prod_info, int(cost["wood"]), int(cost["ore"])]
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
	# 主基地升级后，刷新其他建筑的灰度状态
	if key == "home":
		for k in _building_nodes:
			if k != "home":
				_refresh_label(k)
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
	# 满级时升级按钮置灰
	var btn = state.get("upgrade_btn")
	if btn and is_instance_valid(btn):
		var lv: int = state["level"]
		var maxed: bool = lv >= 3 or (_building_nodes.has("home") and key != "home" and lv >= int(_building_nodes["home"]["level"]))
		btn.modulate = Color(0.7, 0.7, 0.7, 1.0) if maxed else Color.WHITE
		btn.set_meta("disabled", maxed)
func _save_game() -> void:
	var data := {"wood": _wood, "ore": _ore, "gold": _gold, "formation_id": _formation_id, "cleared_level": _cleared_level, "levels": {}, "roles": {}, "owned_roles": _owned_role_ids.duplicate(), "team_ids": _expedition_team_ids.duplicate()}
	for key in _building_nodes:
		data["levels"][key] = _building_nodes[key]["level"]
	for i in _team_slots.size():
		var rid: String = _team_slots[i].get("role_id", "")
		if rid.is_empty():
			continue
		data["roles"][rid] = {
			"level": _team_levels[i] if i < _team_levels.size() else 1,
			"star": _team_stars[i] if i < _team_stars.size() else 1,
		}
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
	if data.has("formation_id"):
		_formation_id = int(data["formation_id"])
	if data.has("cleared_level"):
		_cleared_level = int(data["cleared_level"])
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
	if data.has("roles") and data["roles"] is Dictionary:
		var roles_state: Dictionary = data["roles"]
		for i in _team_slots.size():
			var rid: String = _team_slots[i].get("role_id", "")
			if rid.is_empty() or not roles_state.has(rid):
				continue
			var s = roles_state[rid]
			if not (s is Dictionary):
				continue
			if i < _team_levels.size():
				_team_levels[i] = int(s.get("level", _team_levels[i]))
			if i < _team_stars.size():
				_team_stars[i] = int(s.get("star", _team_stars[i]))
			_refresh_role_label(i)
	# 读档后用 formation_id 查名字并刷新按钮
	_formation_name = _query_formation_name(_formation_id)
	_refresh_formation_btn()

func _query_formation_name(fid: int) -> String:
	var text := _read_table_text("res://asserts/table/formations.txt")
	if text.is_empty():
		return "标准阵"
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() >= 2 and parts[0].is_valid_int() and int(parts[0]) == fid:
			return parts[1]
	return "标准阵"

func _build_upgrade_fx_frames() -> void:
	var res_path := "res://asserts/fx/building_anim_sheet/build_lv_up_anim_sheet.png"
	var tex: Texture2D = load(res_path)
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
		if img == null:
			push_error("Upgrade FX: cannot load " + res_path)
			return
		tex = ImageTexture.create_from_image(img)
	var cols := 5
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
		_build_upgrade_fx_frames()
	if _upgrade_fx_frames == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = _upgrade_fx_frames
	fx.position = pos + Vector2(0, -40)
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
	sq.z_index = 50  # 固定在所有建筑（最低 z=150）之下

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

	var min_y := vp.y * 0.40
	var max_y := vp.y * 0.70
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
	, 0.0, 1.0, dist / speed).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		if not is_instance_valid(sq):
			return
		sq.stop()
		get_tree().create_timer(randf_range(pause_min, pause_max)).timeout.connect(func() -> void:
			_squirrel_wander(sq, target_y)
		)
	)

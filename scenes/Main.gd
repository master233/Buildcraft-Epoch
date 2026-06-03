extends Node2D

@onready var bgm: AudioStreamPlayer = $BGM
@onready var _wood_lbl: Label = $UI/WoodLbl
@onready var _ore_lbl: Label = $UI/OreLbl
@onready var _gold_lbl: Label = $UI/GoldLbl
@warning_ignore("unused_private_class_variable")
@onready var _panel_dim: ColorRect = $UI/PanelDim
@onready var _panel_bg: TextureRect = $UI/BuildingPanel
@onready var _panel_name_lbl: Label = $UI/BuildingPanel/PanelNameLbl
@onready var _panel_info_lbl: RichTextLabel = $UI/BuildingPanel/PanelInfoLbl
@onready var _upgrade_btn: TextureRect = $UI/BuildingPanel/UpgradeBtn
@onready var _upgrade_lbl: Label = $UI/BuildingPanel/UpgradeLbl
@warning_ignore("unused_private_class_variable")
@onready var _close_btn: TextureRect = $UI/BuildingPanel/CloseBtn
@onready var _panel_extra_lbl: RichTextLabel = $UI/BuildingPanel/PanelExtraLbl if $UI/BuildingPanel.has_node("PanelExtraLbl") else null
@warning_ignore("unused_private_class_variable")
@onready var _panel_info_bg: ColorRect = $UI/BuildingPanel/PanelInfoBg if $UI/BuildingPanel.has_node("PanelInfoBg") else null
@warning_ignore("unused_private_class_variable")
@onready var _panel_extra_bg: ColorRect = $UI/BuildingPanel/PanelExtraBg if $UI/BuildingPanel.has_node("PanelExtraBg") else null
@onready var _function_area: Control = $UI/BuildingPanel/FunctionArea

const BUILDING_FUNCTION_SCENES := {
	"tower": "res://scenes/building_panels/TowerPanel.tscn",
	"home":  "res://scenes/building_panels/HeroPanel.tscn",
	"research": "res://scenes/building_panels/ResearchPanel.tscn",
	"tavern": "res://scenes/building_panels/TavernPanel.tscn",
	"lumberyard": "res://scenes/building_panels/ExchangePanel.tscn",
	"mine": "res://scenes/building_panels/ExchangePanel.tscn",
}

var _function_panel_node: Node = null

const BUILDING_SCALE := 0.8
const SQUIRREL_OBSTACLES := [[130.0, 410.0], [870.0, 1210.0]]
const PRODUCE_INTERVAL := 5.0
const PRODUCE_RATES := [3, 6, 12]
const EXCHANGE_AMOUNTS := {1: 10, 2: 100, 3: 1000}
const TOWER_EXP_INTERVAL := 30.0
const TOWER_EXP_PER_LEVEL := 2
const TOWER_DROP_CHANCE := 0.15
const EQUIPMENT_TABLE_PATH := "res://asserts/table/equipment.txt"
const SAVE_PATH := "user://savegame.json"
const LEVELS_TABLE_PATH := "res://asserts/table/levels.txt"
const CHAT_TABLE_PATH := "res://asserts/table/chat.txt"
const CHAT_KEYWORDS_PATH := "res://asserts/table/chat_keywords.txt"
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
const SPEECH_TICK_INTERVAL := 6.0
const SPEECH_DURATION := 3.0

var _panel_rect    := Rect2(0, 0, 1280, 720)
var _upgrade_rect  := Rect2(540, 110, 200, 120)
var _close_rect    := Rect2(1090, 10, 85, 80)
var _gm_rect       := Rect2(0, 0, 160, 36)
var _gm_cmd_rects: Array[Rect2] = []

const BUILDINGS := {
	"home": {
		"ref_size": Vector2(350, 324),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/home1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/home2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/home3_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(640, 375), "display": "主基地", "y_adj": 25,
		"produces": "gold",
	},
	"tower": {
		"ref_size": Vector2(350, 310),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/tower1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tower2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tower3_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(640, 150), "display": "远征塔", "y_adj": 0,
		"produces": "",
	},
	"lumberyard": {
		"ref_size": Vector2(288, 324),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/lumberyard1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/lumberyard2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/lumberyard3_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(210, 275), "display": "伐木场", "y_adj": 25,
		"produces": "wood",
	},
	"mine": {
		"ref_size": Vector2(288, 313),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/mine1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/mine2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/mine3_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(1070, 275), "display": "矿石场", "y_adj": 0,
		"produces": "ore",
	},
	"tavern": {
		"ref_size": Vector2(350, 313),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/tavern1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tavern2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/tavern3_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(270, 510), "display": "酒馆", "y_adj": 0,
		"produces": "",
	},
	"research": {
		"ref_size": Vector2(288, 310),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/research1_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/research2_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/research3_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(1010, 510), "display": "研究院", "y_adj": 0,
		"produces": "",
	},
	"store": {
		"ref_size": Vector2(288, 324),
		"anim_sheets": ["res://asserts/image/building/building_anim_sheet/store_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/store_anim_sheet.png", "res://asserts/image/building/building_anim_sheet/store_anim_sheet.png"], "n_frames": 8,
		"pos": Vector2(380, 160), "display": "装备仓库", "y_adj": 0,
		"produces": "",
	},
}

var _wood: int = 200
var _ore: int = 100
var _gold: int = 0
var _ad_boost_charges: int = 0
var _cleared_level: int = 0
var _level_ids: Array = []
var _gm_bg: Panel = null
var _gm_lbl: Label = null
var _gm_style: StyleBoxFlat = null
var _gm_hovering: bool = false
var _gm_cmd_panel: Panel = null
var _gm_cmd_visible: bool = false
var _gm_cmd_btns: Array = []  # [{bg: Panel, lbl: Label, action: String}]
var _ad_bg: Panel = null
var _ad_lbl: Label = null
var _ad_style: StyleBoxFlat = null
var _ad_hovering: bool = false
var _ad_rect := Rect2(0, 0, 60, 36)
var _ad_texts: Array = []
var _ad_panel_layer: CanvasLayer = null
var _ad_timer: float = 0.0
var _ad_char_index: int = 0
var _ad_current_text: String = ""
var _ad_content_lbl: RichTextLabel = null
var _ad_reward_lbl: Label = null
var _ad_playing: bool = false
const ADS_TABLE_PATH := "res://asserts/table/ads.txt"

var _formation_id: int = 1
var _formation_name: String = "标准阵"
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
var _role_attrs: Dictionary = {}   # role_id → {init_hp, init_atk, init_def, init_speed, lv_hp, …, star_hp, …}
var _level_up_table: Dictionary = {}  # level:int → max_exp:int
var _hero_panel_rid: String = ""   # 英雄面板当前选中的 role_id
var _slot_positions: Array[Vector2] = []
var _layout_by_size: Dictionary = {}  # team_size:int → Array[int] of slot indices
var _role_lines: Dictionary = {}
var _team_slots: Array = []  # [{slot: Node2D, role_id: String, head_top_y, name_lbl, stars_lbl}]
var _role_levels: Dictionary = {}  # rid:String → int
var _role_stars: Dictionary = {}   # rid:String → int
var _role_exps: Dictionary = {}    # rid:String → int
var _role_skills: Dictionary = {}  # rid:String → Array[{id:int, level:int}]
var _skill_table: Dictionary = {}  # {skill_id}_{level} → {name, desc, param1, param2, icon}
var _research_levels: Dictionary = {}  # skill_id(int) → current research level(int)
var _skill_upgrade_cost: Dictionary = {}  # level(int) → cost(int)
var _suit_table: Array = []  # 每个套装仅首条，用于 grid 显示
var _suit_details: Dictionary = {}  # suit_id → [{require_count, effect_desc}]
var _suit_members: Dictionary = {}  # equip_id(int) → suit_name(String)
const SUIT_TABLE_PATH := "res://asserts/table/suit.txt"
const SUIT_MEMBERS_PATH := "res://asserts/table/suit_members.txt"
var _building_configs: Dictionary = {}  # key → [{level, wood_cost, ore_cost, desc}]
const DEFAULT_SKILLS: Array = []
var _equipment_table: Dictionary = {}  # equip_id(int) → {name, slot, atk_min, atk_max, ...}
var _inventory: Array = []             # [{id, level, atk, def, hp, speed, crit, dodge, name, slot}]
var _role_equips: Dictionary = {}      # rid → {slot_name: inventory_index}
var _store_new_badge: TextureRect = null
var _tower_exp_timer: float = 0.0
var _speech_timer: float = 0.0
var _is_anyone_speaking: bool = false
var _last_speech_slot_idx: int = -1

# 聊天框
var _chat_root: Control = null
var _chat_toggle_panel: Panel = null
var _chat_toggle_lbl: Label = null
var _chat_msg_box: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_input: LineEdit = null
var _chat_expanded: bool = false
var _chat_rect := Rect2()
var _chat_toggle_rect := Rect2()
var _chat_preview_panel: Panel = null
var _chat_preview_rtl: RichTextLabel = null

# 聊天自动播放
var _chat_messages: Array = []
var _chat_index: int = 0
var _chat_play_timer: float = 0.0
var _chat_next_delay: float = 1.5

# 聊天关键字回复
var _chat_keywords: Dictionary = {}  # {keyword: [{speaker, content}, ...]}

# 酒馆招募
const TAVERN_RECRUIT_COSTS := [50, 100, 200, 400, 800]
const TAVERN_REFRESH_COST := 100
const TAVERN_AUTO_REFRESH_INTERVAL := 3600.0
const TAVERN_MAX_FREE_REFRESHES := 3
var _tavern_pool: Array = []
var _tavern_auto_timer: float = 0.0
var _tavern_free_refreshes: int = 3
var _chat_keyword_queue: Array = []  # 当前正在播放的关键字回复队列
var _chat_keyword_index: int = 0
var _chat_keyword_playing: bool = false

func _ready() -> void:
	bgm.stream = load("res://asserts/audio/bg1.ogg")
	bgm.volume_db = 0.0
	bgm.play()
	_panel_nodes = []
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_setup")

func _setup() -> void:
	var vp := get_viewport_rect().size
	var half_vp := vp / 2.0
	_panel_movable = []
	_panel_offsets = []

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
	_load_building_configs()
	_load_roles_table()
	_load_role_attrs_table()
	_load_level_up_table()
	_load_skill_table()
	_load_skill_upgrade_cost()
	_load_suit_table()
	_load_suit_members()
	_load_team_layout()
	_load_role_lines()
	_load_equipment_table()
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
	_spawn_gm_button()
	_spawn_chat_box()

	# 从阵型选择场景返回时，读取玩家选中的阵型
	var sel_id = GlobalConfig.get_runtime("selected_formation_id")
	if sel_id != null:
		_formation_id   = int(sel_id)
		_formation_name = String(GlobalConfig.get_runtime("selected_formation_name"))
		GlobalConfig.clear_runtime()
		_refresh_formation_btn()
		_save_game()

func _spawn_gm_button() -> void:
	var ui := $UI
	var vp := get_viewport_rect().size
	_gm_rect = Rect2(vp.x - 74, 12, 60, 36)

	_gm_style = StyleBoxFlat.new()
	_gm_style.bg_color = Color(0.20, 0.28, 0.55)
	_gm_style.set_corner_radius_all(10)
	_gm_style.border_width_top    = 2
	_gm_style.border_width_right  = 2
	_gm_style.border_width_bottom = 3
	_gm_style.border_width_left   = 2
	_gm_style.border_color = Color(0.40, 0.55, 0.95, 1.0)
	_gm_style.shadow_color = Color(0, 0, 0, 0.55)
	_gm_style.shadow_size  = 6
	_gm_style.shadow_offset = Vector2(1, 3)

	_gm_bg = Panel.new()
	_gm_bg.size     = _gm_rect.size
	_gm_bg.position = _gm_rect.position
	_gm_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gm_bg.add_theme_stylebox_override("panel", _gm_style)
	ui.add_child(_gm_bg)

	_gm_lbl = Label.new()
	_gm_lbl.text = "充值"
	_gm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gm_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_gm_lbl.size     = _gm_rect.size
	_gm_lbl.position = _gm_rect.position
	_gm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size  = 22
	ls.font_color = Color(0.92, 0.96, 1.0)
	ls.outline_size  = 2
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.75)
	ls.shadow_size   = 2
	ls.shadow_color  = Color(0, 0, 0, 0.45)
	_gm_lbl.label_settings = ls
	ui.add_child(_gm_lbl)

	_spawn_ad_button(ui)
	_build_gm_cmd_panel(ui)

func _spawn_ad_button(ui: Node) -> void:
	_ad_rect = Rect2(_gm_rect.position.x, _gm_rect.position.y + _gm_rect.size.y + 6.0, 60, 36)
	_ad_style = StyleBoxFlat.new()
	_ad_style.bg_color = Color(0.55, 0.22, 0.06)
	_ad_style.set_corner_radius_all(10)
	_ad_style.border_width_top    = 2
	_ad_style.border_width_right  = 2
	_ad_style.border_width_bottom = 3
	_ad_style.border_width_left   = 2
	_ad_style.border_color = Color(0.90, 0.45, 0.15)
	_ad_style.shadow_color = Color(0, 0, 0, 0.55)
	_ad_style.shadow_size  = 6
	_ad_style.shadow_offset = Vector2(1, 3)
	_ad_bg = Panel.new()
	_ad_bg.size = _ad_rect.size
	_ad_bg.position = _ad_rect.position
	_ad_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ad_bg.add_theme_stylebox_override("panel", _ad_style)
	ui.add_child(_ad_bg)
	_ad_lbl = Label.new()
	_ad_lbl.text = "广告"
	_ad_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ad_lbl.size = _ad_rect.size
	_ad_lbl.position = _ad_rect.position
	_ad_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size = 22
	ls.font_color = Color(1.0, 0.88, 0.55)
	ls.outline_size = 2
	ls.outline_color = Color(0, 0, 0, 0.75)
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.45)
	_ad_lbl.label_settings = ls
	ui.add_child(_ad_lbl)
	_load_ad_texts()

func _load_ad_texts() -> void:
	var text := _read_table_text(ADS_TABLE_PATH)
	if text.is_empty():
		return
	var lines := text.split("\n", false)
	for i in range(1, lines.size()):
		var line: String = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		_ad_texts.append(line)

func _show_ad_panel() -> void:
	if _ad_texts.is_empty():
		return
	if _ad_panel_layer and is_instance_valid(_ad_panel_layer):
		return
	var idx: int = randi() % _ad_texts.size()
	_ad_current_text = _ad_texts[idx]
	_ad_char_index = 0
	_ad_timer = 0.0
	_ad_playing = true
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	_ad_panel_layer = CanvasLayer.new()
	_ad_panel_layer.layer = 50
	add_child(_ad_panel_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ad_panel_layer.add_child(bg)
	var panel := Panel.new()
	panel.size = Vector2(800, 400)
	panel.position = Vector2(240, 160)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.95, 0.92, 0.85)
	pstyle.set_corner_radius_all(16)
	pstyle.border_width_top = 3
	pstyle.border_width_right = 3
	pstyle.border_width_bottom = 3
	pstyle.border_width_left = 3
	pstyle.border_color = Color(0.55, 0.22, 0.06)
	panel.add_theme_stylebox_override("panel", pstyle)
	_ad_panel_layer.add_child(panel)
	# 右上角关闭按钮
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(40, 40)
	close_btn.position = Vector2(240 + 800 - 48, 165)
	_style_tower_btn(close_btn, Color(0.65, 0.15, 0.1), Color(0.9, 0.3, 0.2), Color(1.0, 1.0, 1.0))
	close_btn.pressed.connect(_close_ad_panel)
	_ad_panel_layer.add_child(close_btn)
	# 顶部提醒
	var hint := Label.new()
	hint.text = "广告时长10秒 提前退出拿不到奖励哦~"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(800, 36)
	hint.position = Vector2(240, 170)
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.75, 0.25, 0.1))
	_ad_panel_layer.add_child(hint)
	# 广告内容
	_ad_content_lbl = RichTextLabel.new()
	_ad_content_lbl.size = Vector2(720, 250)
	_ad_content_lbl.position = Vector2(280, 220)
	_ad_content_lbl.bbcode_enabled = false
	_ad_content_lbl.scroll_active = false
	_ad_content_lbl.add_theme_font_override("normal_font", font)
	_ad_content_lbl.add_theme_font_size_override("normal_font_size", 22)
	_ad_content_lbl.add_theme_color_override("default_color", Color(0.15, 0.12, 0.08))
	_ad_content_lbl.text = ""
	_ad_panel_layer.add_child(_ad_content_lbl)
	# 底部奖励提示
	_ad_reward_lbl = Label.new()
	_ad_reward_lbl.text = ""
	_ad_reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_reward_lbl.size = Vector2(800, 40)
	_ad_reward_lbl.position = Vector2(240, 480)
	_ad_reward_lbl.add_theme_font_override("font", font)
	_ad_reward_lbl.add_theme_font_size_override("font_size", 26)
	_ad_reward_lbl.add_theme_color_override("font_color", Color(0.18, 0.75, 0.25))
	_ad_panel_layer.add_child(_ad_reward_lbl)

func _tick_ad(delta: float) -> void:
	if not _ad_playing:
		return
	_ad_timer += delta
	var total_chars: int = _ad_current_text.length()
	var char_interval: float = 10.0 / float(total_chars)
	var target_index: int = mini(int(_ad_timer / char_interval), total_chars)
	if target_index > _ad_char_index:
		_ad_char_index = target_index
		if _ad_content_lbl and is_instance_valid(_ad_content_lbl):
			_ad_content_lbl.text = _ad_current_text.substr(0, _ad_char_index)
	if _ad_timer >= 10.0 and _ad_playing:
		_ad_playing = false
		_ad_boost_charges += 1
		_save_game()
		if _ad_reward_lbl and is_instance_valid(_ad_reward_lbl):
			_ad_reward_lbl.text = "资源加速次数+1"
		if _ad_content_lbl and is_instance_valid(_ad_content_lbl):
			_ad_content_lbl.text = _ad_current_text
		_show_ad_next_btn()

func _show_ad_next_btn() -> void:
	if not (_ad_panel_layer and is_instance_valid(_ad_panel_layer)):
		return
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var next_btn := Button.new()
	next_btn.name = "AdNextBtn"
	next_btn.text = "播放下一条"
	next_btn.size = Vector2(160, 44)
	next_btn.position = Vector2(560, 520)
	_style_tower_btn(next_btn, Color(0.55, 0.22, 0.06), Color(0.90, 0.45, 0.15), Color(1.0, 0.88, 0.55))
	next_btn.pressed.connect(_play_next_ad)
	_ad_panel_layer.add_child(next_btn)

func _play_next_ad() -> void:
	if _ad_texts.is_empty():
		return
	var idx: int = randi() % _ad_texts.size()
	_ad_current_text = _ad_texts[idx]
	_ad_char_index = 0
	_ad_timer = 0.0
	_ad_playing = true
	if _ad_content_lbl and is_instance_valid(_ad_content_lbl):
		_ad_content_lbl.text = ""
	if _ad_reward_lbl and is_instance_valid(_ad_reward_lbl):
		_ad_reward_lbl.text = ""
	var old_btn = _ad_panel_layer.get_node_or_null("AdNextBtn")
	if old_btn:
		old_btn.queue_free()

func _close_ad_panel() -> void:
	if _ad_panel_layer and is_instance_valid(_ad_panel_layer):
		_ad_panel_layer.queue_free()
		_ad_panel_layer = null
	_ad_playing = false
	_ad_content_lbl = null
	_ad_reward_lbl = null
	if _panel_visible and (_panel_key == "lumberyard" or _panel_key == "mine"):
		_refresh_exchange_boost(_panel_key)

func _build_gm_cmd_panel(ui: Node) -> void:
	var commands := [
		{"text": "添加资源", "action": "add_resources"},
		{"text": "获得所有角色1个", "action": "grant_all_roles"},
		{"text": "所有角色学习技能", "action": "learn_skill"},
		{"text": "添加所有装备", "action": "add_all_equip"},
		{"text": "重置数据", "action": "reset"},
	]
	var pad := 8.0
	var btn_h := 36.0
	var gap := 6.0
	var panel_w := 200.0
	var panel_h := pad * 2 + btn_h * commands.size() + gap * (commands.size() - 1)
	var panel_x := _gm_rect.position.x + _gm_rect.size.x - panel_w
	var panel_y := _gm_rect.position.y + _gm_rect.size.y + 6.0

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.15, 0.18, 0.30, 0.95)
	pstyle.set_corner_radius_all(10)
	pstyle.border_width_top    = 2
	pstyle.border_width_right  = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left   = 2
	pstyle.border_color = Color(0.40, 0.55, 0.95, 1.0)
	pstyle.shadow_color = Color(0, 0, 0, 0.55)
	pstyle.shadow_size  = 8

	_gm_cmd_panel = Panel.new()
	_gm_cmd_panel.size     = Vector2(panel_w, panel_h)
	_gm_cmd_panel.position = Vector2(panel_x, panel_y)
	_gm_cmd_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gm_cmd_panel.add_theme_stylebox_override("panel", pstyle)
	_gm_cmd_panel.visible = false
	ui.add_child(_gm_cmd_panel)

	_gm_cmd_btns.clear()
	_gm_cmd_rects.clear()
	for i in commands.size():
		var cmd: Dictionary = commands[i]
		var by := panel_y + pad + i * (btn_h + gap)
		var btn_rect := Rect2(panel_x + pad, by, panel_w - pad * 2, btn_h)

		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color(0.25, 0.32, 0.60)
		bstyle.set_corner_radius_all(8)
		bstyle.border_width_top    = 1
		bstyle.border_width_right  = 1
		bstyle.border_width_bottom = 2
		bstyle.border_width_left   = 1
		bstyle.border_color = Color(0.55, 0.70, 1.0, 0.9)

		var bg := Panel.new()
		bg.size     = btn_rect.size
		bg.position = btn_rect.position
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_theme_stylebox_override("panel", bstyle)
		bg.visible = false
		ui.add_child(bg)

		var lbl := Label.new()
		lbl.text = String(cmd["text"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size     = btn_rect.size
		lbl.position = btn_rect.position
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bls := LabelSettings.new()
		bls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		bls.font_size  = 20
		bls.font_color = Color(0.95, 0.98, 1.0)
		bls.outline_size  = 2
		bls.outline_color = Color(0.0, 0.0, 0.0, 0.8)
		lbl.label_settings = bls
		lbl.visible = false
		ui.add_child(lbl)

		_gm_cmd_btns.append({"bg": bg, "lbl": lbl, "action": String(cmd["action"])})
		_gm_cmd_rects.append(btn_rect)

func _set_gm_cmd_visible(v: bool) -> void:
	_gm_cmd_visible = v
	if _gm_cmd_panel and is_instance_valid(_gm_cmd_panel):
		_gm_cmd_panel.visible = v
	for entry in _gm_cmd_btns:
		var bg = entry.get("bg", null)
		var lbl = entry.get("lbl", null)
		if bg and is_instance_valid(bg):
			bg.visible = v
		if lbl and is_instance_valid(lbl):
			lbl.visible = v

func _gm_add_resources() -> void:
	_wood += 1000
	_ore  += 1000
	_gold += 1000
	_refresh_hud()
	_save_game()

func _gm_grant_all_roles() -> void:
	var max_star: int = GlobalConfig.get_int("max_star_level", 6)
	var any_new := false
	for i in range(10001, 10006):
		var rid := str(i)
		if not _roles.has(rid):
			continue
		if rid in _owned_role_ids:
			_ensure_role_data(rid)
			var cur_star: int = int(_role_stars.get(rid, 1))
			if cur_star < max_star:
				_role_stars[rid] = cur_star + 1
				_refresh_role_label_for(rid)
			else:
				_gold += 200
		else:
			_owned_role_ids.append(rid)
			_ensure_role_data(rid)
			if _expedition_team_ids.size() < MAX_EXPEDITION_SIZE and not rid in _expedition_team_ids:
				_expedition_team_ids.append(rid)
			any_new = true
	_save_game()
	if any_new:
		_clear_team_nodes()
		_resolve_team_from_owned()
		_place_expedition_team()
		_load_game()
	_refresh_hud()

func _ensure_default_skill(rid: String) -> void:
	if rid.is_empty():
		return
	var role_data: Dictionary = _roles.get(rid, {})
	var def_sid: int = int(role_data.get("default_skill", 0))
	if def_sid <= 0:
		return
	var cur: Array = _role_skills.get(rid, []) if _role_skills.get(rid, null) is Array else []
	for s in cur:
		if s is Dictionary and int(s.get("id", 0)) == def_sid:
			return
	cur.insert(0, {"id": def_sid, "level": 1})
	_role_skills[rid] = cur

func _ensure_role_data(rid: String) -> void:
	if rid.is_empty() or not _roles.has(rid):
		return
	var role_data: Dictionary = _roles[rid]
	if not _role_levels.has(rid):
		_role_levels[rid] = int(role_data.get("init_level", 1))
	if not _role_stars.has(rid):
		_role_stars[rid] = int(role_data.get("init_star", 1))
	if not _role_exps.has(rid):
		_role_exps[rid] = 0
	if not _role_skills.has(rid):
		var initial_skills: Array = _default_skills_copy()
		var def_sid: int = int(role_data.get("default_skill", 0))
		if def_sid > 0:
			initial_skills.insert(0, {"id": def_sid, "level": 1})
		_role_skills[rid] = initial_skills
	else:
		_ensure_default_skill(rid)

func _load_skill_table() -> void:
	_skill_table.clear()
	var text := _read_table_text("res://asserts/table/skill.txt")
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 6:
			continue
		var sid_s: String = (parts[0] as String).strip_edges()
		var lv_s: String = (parts[1] as String).strip_edges()
		if not sid_s.is_valid_int() or not lv_s.is_valid_int():
			continue
		var key := "%s_%s" % [sid_s, lv_s]
		var desc_raw: String = parts[3] if parts.size() > 3 else ""
		var p1: String = parts[4] if parts.size() > 4 else "0"
		var p2: String = parts[5] if parts.size() > 5 else "0"
		var desc_bbcode := desc_raw.replace("{p1}", "[color=#2ebf40]" + p1 + "[/color]").replace("{p2}", "[color=#2ebf40]" + p2 + "[/color]")
		_skill_table[key] = {
			"name": parts[2] if parts.size() > 2 else "",
			"desc": desc_bbcode,
			"icon": parts[6] if parts.size() > 6 else "",
		}

func _load_skill_upgrade_cost() -> void:
	_skill_upgrade_cost.clear()
	var text := _read_table_text("res://asserts/table/skill_upgrade_cost.txt")
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 2:
			continue
		var lv := int((parts[0] as String).strip_edges())
		var cost := int((parts[1] as String).strip_edges())
		_skill_upgrade_cost[lv] = cost

func _load_suit_table() -> void:
	_suit_table.clear()
	_suit_details.clear()
	var text := _read_table_text(SUIT_TABLE_PATH)
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	var seen_suits: Dictionary = {}
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 6:
			continue
		var suit_id: String = (parts[1] as String).strip_edges()
		var entry := {
			"suit_id": suit_id,
			"name": (parts[2] as String).strip_edges(),
			"icon": (parts[3] as String).strip_edges(),
			"require_count": int((parts[4] as String).strip_edges()),
			"effect_desc": (parts[5] as String).strip_edges(),
		}
		if not seen_suits.has(suit_id):
			seen_suits[suit_id] = true
			_suit_table.append(entry)
		if not _suit_details.has(suit_id):
			_suit_details[suit_id] = []
		var bonus := {"require_count": entry["require_count"], "effect_desc": entry["effect_desc"],
			"atk": int(parts[6]) if parts.size() > 6 else 0,
			"def": int(parts[7]) if parts.size() > 7 else 0,
			"hp": int(parts[8]) if parts.size() > 8 else 0,
			"speed": int(parts[9]) if parts.size() > 9 else 0,
			"crit": int(parts[10]) if parts.size() > 10 else 0,
			"dodge": int(parts[11]) if parts.size() > 11 else 0,
		}
		_suit_details[suit_id].append(bonus)

func _load_suit_members() -> void:
	_suit_members.clear()
	var text := _read_table_text(SUIT_MEMBERS_PATH)
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 3:
			continue
		var suit_name: String = (parts[1] as String).strip_edges()
		var id_list: String = (parts[2] as String).strip_edges()
		for eid_str in id_list.split(","):
			var eid: int = int(eid_str.strip_edges())
			if eid > 0:
				_suit_members[eid] = suit_name

func _load_building_configs() -> void:
	_building_configs.clear()
	for key in BUILDINGS.keys():
		var path := "res://asserts/table/build_%s.txt" % key
		var text := _read_table_text(path)
		if text.is_empty():
			continue
		var raw := text.split("\n", false)
		if raw.size() < 1:
			continue
		var headers := (raw[0] as String).strip_edges().split("\t")
		var levels: Array = []
		for i in range(1, raw.size()):
			var line: String = (raw[i] as String).strip_edges()
			if line.is_empty() or line.begins_with("#"):
				continue
			var parts := line.split("\t")
			if parts.size() < 4:
				continue
			var entry := {}
			for j in min(parts.size(), headers.size()):
				var h: String = (headers[j] as String).strip_edges()
				var v: String = (parts[j] as String).strip_edges()
				if h in ["level", "wood_cost", "ore_cost", "gold_cost", "skill_max_lv"]:
					entry[h] = int(v)
				else:
					entry[h] = v
			levels.append(entry)
		_building_configs[key] = levels

func _load_all_skill_ids() -> Array:
	var text := _read_table_text("res://asserts/table/skill.txt")
	if text.is_empty():
		return []
	var raw := text.split("\n", false)
	var seen: Dictionary = {}
	var ids: Array = []
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 1:
			continue
		var sid_s: String = (parts[0] as String).strip_edges()
		if not sid_s.is_valid_int():
			continue
		var sid := int(sid_s)
		if seen.has(sid):
			continue
		seen[sid] = true
		ids.append(sid)
	ids.sort()
	return ids

func _gm_learn_next_skill() -> void:
	var all_ids := _load_all_skill_ids()
	if all_ids.is_empty():
		return
	for entry in _team_slots:
		var rid: String = String(entry.get("role_id", ""))
		if rid.is_empty():
			continue
		_ensure_role_data(rid)
		var cur: Array = _role_skills.get(rid, []) if _role_skills.get(rid, null) is Array else []
		var owned: Dictionary = {}
		for s in cur:
			if s is Dictionary:
				owned[int(s.get("id", 0))] = true
		for sid in all_ids:
			if not owned.has(sid):
				cur.append({"id": sid, "level": 1})
				break
		_role_skills[rid] = cur
	_save_game()

func _gm_add_all_equip() -> void:
	if _equipment_table.is_empty():
		return
	var tower_lv: int = _building_nodes["tower"]["level"] if _building_nodes.has("tower") else 1
	var equip_level: int = tower_lv * 10
	var scale: float = 1.0 + (equip_level - 10) * 0.10
	for eid in _equipment_table.keys():
		var tpl: Dictionary = _equipment_table[eid]
		var item := {
			"id": eid,
			"level": equip_level,
			"name": tpl["name"],
			"slot": tpl["slot"],
			"icon": tpl["icon"],
			"atk": int(randi_range(tpl["atk_min"], tpl["atk_max"]) * scale),
			"def": int(randi_range(tpl["def_min"], tpl["def_max"]) * scale),
			"hp": int(randi_range(tpl["hp_min"], tpl["hp_max"]) * scale),
			"speed": int(randi_range(tpl["speed_min"], tpl["speed_max"]) * scale),
			"crit": int(randi_range(tpl["crit_min"], tpl["crit_max"]) * scale),
			"dodge": int(randi_range(tpl["dodge_min"], tpl["dodge_max"]) * scale),
			"is_new": true,
		}
		_inventory.append(item)
	_refresh_store_new_badge()
	_save_game()

const BATTLE_SCENE_PATH := "res://scenes/BattleScene.tscn"

func _refresh_formation_btn() -> void:
	# 从阵型场景返回后更新远征塔面板内的阵型按钮文字
	if _function_panel_node and is_instance_valid(_function_panel_node):
		var form_btn: Button = _function_panel_node.get_node_or_null("ActionRow/FormationBtn")
		if form_btn:
			form_btn.text = _formation_name

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

func _load_level_names() -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(LEVELS_TABLE_PATH, FileAccess.READ)
	if file == null:
		return result
	var text := file.get_as_text()
	file.close()
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return result
	var headers := (raw[0] as String).strip_edges().split("\t")
	var name_col := -1
	for j in headers.size():
		if headers[j] == "name":
			name_col = j
			break
	if name_col < 0:
		return result
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() <= name_col:
			continue
		var lid_str: String = (parts[0] as String).strip_edges()
		if lid_str.is_valid_int():
			result[lid_str] = (parts[name_col] as String).strip_edges()
	return result

func _reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_wood = 200
	_ore = 100
	_gold = 0
	_cleared_level = 0
	_chat_index = 0
	for key in _building_nodes:
		_building_nodes[key]["level"] = 1
		_apply_anim_sheet(key, 1)
		_refresh_label(key)
	_clear_team_nodes()
	_role_levels.clear()
	_role_stars.clear()
	_role_exps.clear()
	_role_skills.clear()
	_inventory.clear()
	_role_equips.clear()
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

func _has_popup_layer() -> bool:
	for child in get_children():
		if child is CanvasLayer and child.layer >= 20:
			return true
	return false

func _input(event: InputEvent) -> void:
	if not bgm.playing:
		bgm.play()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _has_popup_layer():
				return
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
	_tower_exp_timer += delta
	if _tower_exp_timer >= TOWER_EXP_INTERVAL:
		_tower_exp_timer = 0.0
		_tick_tower_exp()
	_speech_timer += delta
	if _speech_timer >= SPEECH_TICK_INTERVAL:
		_speech_timer = 0.0
		_tick_speech()
	_tick_chat(delta)
	_tick_tavern_auto_refresh(delta)
	_tick_ad(delta)
	if _ad_style != null:
		var ad_hov := _ad_rect.has_point(get_viewport().get_mouse_position())
		if ad_hov != _ad_hovering:
			_ad_hovering = ad_hov
			_ad_style.bg_color = Color(0.70, 0.30, 0.10) if ad_hov else Color(0.55, 0.22, 0.06)
			_ad_style.border_color = Color(1.0, 0.55, 0.20) if ad_hov else Color(0.90, 0.45, 0.15)
	if _gm_style != null:
		var hov := _gm_rect.has_point(get_viewport().get_mouse_position())
		if hov != _gm_hovering:
			_gm_hovering = hov
			_gm_style.bg_color     = Color(0.28, 0.36, 0.68) if hov else Color(0.20, 0.28, 0.55)
			_gm_style.border_color = Color(0.55, 0.70, 1.0) if hov else Color(0.40, 0.55, 0.95)

func _place_buildings() -> void:
	for key in BUILDINGS:
		var cfg = BUILDINGS[key]
		var container := Node2D.new()
		container.name = key.capitalize()
		container.position = cfg["pos"]
		container.z_index = int(cfg["pos"].y)
		add_child(container)

		var sheet_tex: Texture2D = load(cfg["anim_sheets"][0])
		var n_frames: int = cfg["n_frames"]
		@warning_ignore("integer_division")
		var frame_w := sheet_tex.get_width() / n_frames
		var frame_h := sheet_tex.get_height()
		var ref_size: Vector2 = cfg["ref_size"]
		var scale_by_w := (ref_size.x * BUILDING_SCALE) / float(frame_w)
		var scale_by_h := (ref_size.y * BUILDING_SCALE) / float(frame_h)
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
		var display_node: Node2D = anim_sprite
		var label_y_offset: float = -(frame_h * anim_scale * 0.35) - 8.0 + cfg["y_adj"]
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
		if key == "store":
			var badge := TextureRect.new()
			badge.texture = load("res://asserts/image/ui/redpoint.png")
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.size = Vector2(24, 24)
			badge.position = Vector2(50.0, label_y_offset - 4)
			badge.visible = false
			container.add_child(badge)
			_store_new_badge = badge

func _place_expedition_team() -> void:
	var team_size: int = _expedition_team_ids.size()
	if team_size <= 0 or _slot_positions.is_empty():
		return
	var layout: Array = _layout_by_size.get(team_size, [])
	if layout.is_empty():
		push_warning("team_layout.txt missing layout_size_%d" % team_size)
		return
	# 初始化每个角色的属性数据（按 role_id 持久化，不随队伍变动重置）
	for rid in _owned_role_ids:
		_ensure_role_data(rid)
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
		@warning_ignore("integer_division")
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
			@warning_ignore("integer_division")
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
			@warning_ignore("integer_division")
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
			@warning_ignore("integer_division")
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
			@warning_ignore("integer_division")
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
	var lv: int = int(_role_levels.get(role_id, role_data.get("init_level", 1)))
	var star: int = int(_role_stars.get(role_id, role_data.get("init_star", 1)))
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

func _refresh_role_label_for(rid: String) -> void:
	for i in _team_slots.size():
		if String(_team_slots[i].get("role_id", "")) == rid:
			_refresh_role_label(i)
			return


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
			"default_skill": int(entry.get("default_skill", "0")),
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
	_panel_bg.visible = v
	_panel_visible = v
	if not v:
		_unload_function_panel()
	if _gm_bg and is_instance_valid(_gm_bg):
		_gm_bg.visible = not v
	if _gm_lbl and is_instance_valid(_gm_lbl):
		_gm_lbl.visible = not v
	if _ad_bg and is_instance_valid(_ad_bg):
		_ad_bg.visible = not v
	if _ad_lbl and is_instance_valid(_ad_lbl):
		_ad_lbl.visible = not v
	if v:
		_set_gm_cmd_visible(false)
		_play_ui_open_sfx()

func _load_function_panel(key: String) -> void:
	_unload_function_panel()
	if not BUILDING_FUNCTION_SCENES.has(key):
		return
	var scene: PackedScene = load(BUILDING_FUNCTION_SCENES[key])
	if scene == null:
		return
	_function_panel_node = scene.instantiate()
	_function_area.add_child(_function_panel_node)
	if _function_panel_node is Control:
		(_function_panel_node as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 连接关卡按钮（远征塔）
	if key == "tower":
		_connect_tower_buttons()
	elif key == "home":
		_connect_hero_panel()
	elif key == "research":
		_connect_research_panel()
	elif key == "tavern":
		_connect_tavern_panel()
	elif key == "lumberyard" or key == "mine":
		_connect_exchange_panel(key)

func _unload_function_panel() -> void:
	if _function_panel_node and is_instance_valid(_function_panel_node):
		_function_panel_node.queue_free()
	_function_panel_node = null

# ─── 英雄面板（主基地）────────────────────────────────────────────────────────

const ROLE_ATTRS_TABLE_PATH := "res://asserts/table/role_attrs.txt"
const LEVEL_UP_TABLE_PATH   := "res://asserts/table/level_up.txt"

func _load_role_attrs_table() -> void:
	var text := _read_table_text(ROLE_ATTRS_TABLE_PATH)
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
		_role_attrs[rid] = {
			"init_hp":    int(entry.get("init_hp",    "300")),
			"init_atk":   int(entry.get("init_atk",   "50")),
			"init_def":   int(entry.get("init_def",   "30")),
			"init_speed": int(entry.get("init_speed", "80")),
			"lv_hp":      int(entry.get("lv_hp",      "10")),
			"lv_atk":     int(entry.get("lv_atk",     "3")),
			"lv_def":     int(entry.get("lv_def",     "2")),
			"lv_speed":   int(entry.get("lv_speed",   "1")),
			"star_hp":    int(entry.get("star_hp",    "20")),
			"star_atk":   int(entry.get("star_atk",   "10")),
			"star_def":   int(entry.get("star_def",   "5")),
			"star_speed": int(entry.get("star_speed", "2")),
		}

func _load_level_up_table() -> void:
	var text := _read_table_text(LEVEL_UP_TABLE_PATH)
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 2:
			continue
		var lv := int((parts[0] as String).strip_edges())
		var mx := int((parts[1] as String).strip_edges())
		_level_up_table[lv] = mx

func _load_equipment_table() -> void:
	var text := _read_table_text(EQUIPMENT_TABLE_PATH)
	if text.is_empty():
		return
	var raw := text.split("\n", false)
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 16:
			continue
		var eid := int((parts[0] as String).strip_edges())
		_equipment_table[eid] = {
			"name": (parts[1] as String).strip_edges(),
			"slot": (parts[2] as String).strip_edges(),
			"icon": (parts[3] as String).strip_edges(),
			"atk_min": int(parts[4]), "atk_max": int(parts[5]),
			"def_min": int(parts[6]), "def_max": int(parts[7]),
			"hp_min": int(parts[8]), "hp_max": int(parts[9]),
			"speed_min": int(parts[10]), "speed_max": int(parts[11]),
			"crit_min": int(parts[12]), "crit_max": int(parts[13]),
			"dodge_min": int(parts[14]), "dodge_max": int(parts[15]),
		}

func _hero_calc_attrs(rid: String) -> Dictionary:
	var lv   := int(_role_levels.get(rid, 1))
	var star := int(_role_stars.get(rid, 1))
	if not _role_attrs.has(rid):
		return {"hp": 300, "atk": 50, "def": 30, "spd": 80}
	var a: Dictionary = _role_attrs[rid]
	var hp: int  = a.init_hp    + (lv - 1) * a.lv_hp    + star * a.star_hp
	var atk: int = a.init_atk   + (lv - 1) * a.lv_atk   + star * a.star_atk
	var def: int = a.init_def   + (lv - 1) * a.lv_def   + star * a.star_def
	var spd: int = a.init_speed + (lv - 1) * a.lv_speed + star * a.star_speed
	# 装备属性加成
	var equips: Dictionary = _role_equips.get(rid, {}) if _role_equips.get(rid, null) is Dictionary else {}
	var suit_counts: Dictionary = {}
	for sk in equips.keys():
		var inv_idx: int = int(equips[sk])
		if inv_idx >= 0 and inv_idx < _inventory.size():
			var item: Dictionary = _inventory[inv_idx]
			atk += int(item.get("atk", 0))
			def += int(item.get("def", 0))
			hp  += int(item.get("hp", 0))
			spd += int(item.get("speed", 0))
			var eid: int = int(item.get("id", 0))
			if _suit_members.has(eid):
				var sn: String = _suit_members[eid]
				suit_counts[sn] = int(suit_counts.get(sn, 0)) + 1
	# 套装属性加成
	for sn in suit_counts.keys():
		var count: int = int(suit_counts[sn])
		for entry in _suit_table:
			if String(entry["name"]) == sn:
				var sid: String = String(entry["suit_id"])
				if _suit_details.has(sid):
					for bonus in _suit_details[sid]:
						if int(bonus["require_count"]) <= count:
							atk += int(bonus.get("atk", 0))
							def += int(bonus.get("def", 0))
							hp  += int(bonus.get("hp", 0))
							spd += int(bonus.get("speed", 0))
				break
	return {"hp": hp, "atk": atk, "def": def, "spd": spd}

func _connect_research_panel() -> void:
	if _function_panel_node == null or not is_instance_valid(_function_panel_node):
		return
	var skill_grid: GridContainer = _function_panel_node.get_node_or_null("SkillScroll/ContentVBox/SkillGrid")
	if skill_grid == null:
		return
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var all_ids := _load_all_skill_ids()
	var talent_ids: Array = []
	var common_ids: Array = []
	for sid in all_ids:
		if int(sid) >= 40000:
			talent_ids.append(sid)
		else:
			common_ids.append(sid)
	var sorted_ids: Array = talent_ids + common_ids
	for sid in sorted_ids:
		var lv: int = int(_research_levels.get(sid, 1))
		var key := "%d_%d" % [sid, lv]
		var info: Dictionary = _skill_table.get(key, {})
		var sk_name: String = info.get("name", "")
		var icon_path: String = info.get("icon", "")

		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)
		slot_vbox.custom_minimum_size = Vector2(80, 100)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		slot_vbox.add_child(icon_rect)

		var info_hbox := HBoxContainer.new()
		info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		info_hbox.add_theme_constant_override("separation", 4)
		var name_lbl := Label.new()
		name_lbl.text = sk_name
		var name_ls := LabelSettings.new()
		name_ls.font = font
		name_ls.font_size = 13
		name_ls.font_color = Color(0.22, 0.13, 0.06, 1)
		name_ls.outline_size = 1
		name_ls.outline_color = Color(1, 0.96, 0.85, 0.4)
		name_lbl.label_settings = name_ls
		info_hbox.add_child(name_lbl)
		var lv_lbl := Label.new()
		lv_lbl.text = "Lv.%d" % lv
		var ls := LabelSettings.new()
		ls.font = font
		ls.font_size = 13
		ls.font_color = Color(0.18, 0.75, 0.25, 1)
		ls.outline_size = 1
		ls.outline_color = Color(0, 0.1, 0, 0.6)
		lv_lbl.label_settings = ls
		info_hbox.add_child(lv_lbl)
		slot_vbox.add_child(info_hbox)

		var btn := Button.new()
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var captured_sid: int = int(sid)
		btn.pressed.connect(func(): _show_skill_tip(captured_sid, int(_research_levels.get(captured_sid, 1))))

		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(80, 100)
		wrapper.add_child(slot_vbox)
		wrapper.add_child(btn)
		skill_grid.add_child(wrapper)

	# ─── 套装效果 Grid ───
	var suit_grid: GridContainer = _function_panel_node.get_node_or_null("SkillScroll/ContentVBox/SuitGrid")
	if suit_grid == null:
		return
	for entry in _suit_table:
		var s_name: String = entry["name"]
		var s_icon: String = entry["icon"]

		var slot_vbox2 := VBoxContainer.new()
		slot_vbox2.add_theme_constant_override("separation", 2)
		slot_vbox2.custom_minimum_size = Vector2(80, 100)

		var icon_rect2 := TextureRect.new()
		icon_rect2.custom_minimum_size = Vector2(64, 64)
		icon_rect2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not s_icon.is_empty() and ResourceLoader.exists(s_icon):
			icon_rect2.texture = load(s_icon)
		slot_vbox2.add_child(icon_rect2)

		var name_lbl2 := Label.new()
		name_lbl2.text = s_name
		name_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var name_ls2 := LabelSettings.new()
		name_ls2.font = font
		name_ls2.font_size = 13
		name_ls2.font_color = Color(0.22, 0.13, 0.06, 1)
		name_ls2.outline_size = 1
		name_ls2.outline_color = Color(1, 0.96, 0.85, 0.4)
		name_lbl2.label_settings = name_ls2
		slot_vbox2.add_child(name_lbl2)

		var btn2 := Button.new()
		btn2.flat = true
		btn2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var captured_suit_id: String = entry["suit_id"]
		var captured_suit_name: String = s_name
		var captured_suit_icon: String = s_icon
		btn2.pressed.connect(func(): _show_suit_tip(captured_suit_id, captured_suit_name, captured_suit_icon))

		var wrapper2 := Control.new()
		wrapper2.custom_minimum_size = Vector2(80, 100)
		wrapper2.add_child(slot_vbox2)
		wrapper2.add_child(btn2)
		suit_grid.add_child(wrapper2)

func _hero_panel_get_node(path: String) -> Node:
	return _function_panel_node.get_node_or_null(path) if _function_panel_node and is_instance_valid(_function_panel_node) else null

func _connect_hero_panel() -> void:
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var star_tex: Texture2D = load(STAR_ICON_PATH)

	# 左侧列表：每个已拥有英雄一张卡片
	var vbox := _hero_panel_get_node("HeroList/HeroListVBox")
	if vbox == null:
		return

	if _owned_role_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "尚无英雄"
		(empty_lbl as Label).label_settings = _make_hero_label_settings(font, 17)
		vbox.add_child(empty_lbl)
		return

	var first_rid: String = _owned_role_ids[0]
	for rid in _owned_role_ids:
		var rd: Dictionary = _roles.get(rid, {})
		var lv: int = int(_role_levels.get(rid, 1))
		var star: int = int(_role_stars.get(rid, 1))

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.55, 0.38, 0.18, 0.55)
		card_style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_style)
		card.custom_minimum_size = Vector2(182, 64)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		card.add_child(hbox)

		# 头像
		var role_idx: int = int(rid) - 10000
		var avatar_path := "res://asserts/image/role/role%d_avatar.png" % role_idx
		var avatar := TextureRect.new()
		var avatar_tex: Texture2D = load(avatar_path) if ResourceLoader.exists(avatar_path) else null
		if avatar_tex:
			avatar.texture = avatar_tex
		avatar.custom_minimum_size = Vector2(60, 60)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(avatar)

		# 名字 + 等级 + 星
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 2)
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = String(rd.get("name", rid))
		name_lbl.label_settings = _make_hero_label_settings(font, 18)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_child(name_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text = "Lv.%d" % lv
		lv_lbl.label_settings = _make_hero_label_settings(font, 16)
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_child(lv_lbl)

		var stars_hbox := HBoxContainer.new()
		stars_hbox.add_theme_constant_override("separation", 1)
		stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_child(stars_hbox)
		for _s in maxi(star, 0):
			var sr := TextureRect.new()
			sr.texture = star_tex
			sr.custom_minimum_size = Vector2(14, 14)
			sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stars_hbox.add_child(sr)

		vbox.add_child(card)

		var sel_rid := rid
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_show_hero_detail(sel_rid)
		)

		card.set_meta("rid", rid)
		card.set_meta("base_style", card_style)

	_show_hero_detail(first_rid)

func _hero_highlight_card(selected_rid: String) -> void:
	var vbox := _hero_panel_get_node("HeroList/HeroListVBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		if not child.has_meta("rid"):
			continue
		var rid: String = String(child.get_meta("rid"))
		var st: StyleBoxFlat = child.get_meta("base_style")
		if rid == selected_rid:
			st.bg_color = Color(0.96, 0.82, 0.42, 0.92)
		else:
			st.bg_color = Color(0.55, 0.38, 0.18, 0.55)

func _show_hero_detail(rid: String) -> void:
	_hero_panel_rid = rid
	_hero_highlight_card(rid)
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var rd: Dictionary = _roles.get(rid, {})
	var lv: int   = int(_role_levels.get(rid, 1))
	var star: int = int(_role_stars.get(rid, 1))
	var exp: int  = int(_role_exps.get(rid, 0))
	var max_exp: int = int(_level_up_table.get(lv, 0))
	var max_star: int = GlobalConfig.get_int("max_star_level", 6)

	# 名字
	var name_lbl: Label = _hero_panel_get_node("DetailArea/LeftCol/HeroNameLbl")
	if name_lbl:
		name_lbl.text = String(rd.get("name", rid))

	# 头像
	var avatar_rect: TextureRect = _hero_panel_get_node("DetailArea/LeftCol/AvatarRect")
	if avatar_rect:
		var role_idx: int = int(rid) - 10000
		var ap := "res://asserts/image/role/role%d_avatar.png" % role_idx
		if ResourceLoader.exists(ap):
			avatar_rect.texture = load(ap)
		else:
			avatar_rect.texture = null

	# 头像下方星级
	var avatar_stars: HBoxContainer = _hero_panel_get_node("DetailArea/LeftCol/AvatarStarsBox")
	if avatar_stars:
		for c in avatar_stars.get_children():
			avatar_stars.remove_child(c)
			c.queue_free()
		var star_tex: Texture2D = load(STAR_ICON_PATH)
		for _s in maxi(star, 0):
			var sr := TextureRect.new()
			sr.texture = star_tex
			sr.custom_minimum_size = Vector2(22, 22)
			sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar_stars.add_child(sr)

	# 星星下方等级标签
	var exp_lbl: Label = _hero_panel_get_node("DetailArea/LeftCol/AvatarExpLbl")
	if exp_lbl:
		exp_lbl.text = "Lv.%d" % lv
	# 经验条
	var exp_bar: ProgressBar = _hero_panel_get_node("DetailArea/LeftCol/ExpBarContainer/AvatarExpBar")
	if exp_bar:
		if max_exp > 0:
			exp_bar.max_value = max_exp
			exp_bar.value = exp
		else:
			exp_bar.max_value = 1
			exp_bar.value = 1
	# 经验条内数值
	var exp_bar_lbl: Label = _hero_panel_get_node("DetailArea/LeftCol/ExpBarContainer/ExpBarLbl")
	if exp_bar_lbl:
		if max_exp > 0:
			exp_bar_lbl.text = "%d/%d" % [exp, max_exp]
		else:
			exp_bar_lbl.text = "MAX"

	# 基础属性（属性名默认色，数值绿色）
	var attrs := _hero_calc_attrs(rid)
	var attr_hp: RichTextLabel  = _hero_panel_get_node("DetailArea/LeftCol/AttrBox/AttrHp")
	var attr_atk: RichTextLabel = _hero_panel_get_node("DetailArea/LeftCol/AttrBox/AttrAtk")
	var attr_def: RichTextLabel = _hero_panel_get_node("DetailArea/LeftCol/AttrBox/AttrDef")
	var attr_spd: RichTextLabel = _hero_panel_get_node("DetailArea/LeftCol/AttrBox/AttrSpd")
	for rtl in [attr_hp, attr_atk, attr_def, attr_spd]:
		if rtl:
			rtl.add_theme_font_override("normal_font", font)
			rtl.add_theme_font_size_override("normal_font_size", 17)
			rtl.add_theme_color_override("default_color", Color(0.22, 0.13, 0.06, 1))
	if attr_hp:  attr_hp.text  = "生命：[color=#2ebf40]%d[/color]"  % attrs.hp
	if attr_atk: attr_atk.text = "攻击：[color=#2ebf40]%d[/color]"  % attrs.atk
	if attr_def: attr_def.text = "防御：[color=#2ebf40]%d[/color]"  % attrs.def
	if attr_spd: attr_spd.text = "速度：[color=#2ebf40]%d[/color]"  % attrs.spd

	# 装备占位
	var equip_grid: GridContainer = _hero_panel_get_node("DetailArea/RightCol/EquipGrid")
	var equip_lbl: RichTextLabel = _hero_panel_get_node("DetailArea/RightCol/EquipLbl")
	var equip_slot_names := ["添加\n武器", "添加\n头盔", "添加\n胸甲", "添加\n手套", "添加\n裤子", "添加\n鞋子", "添加\n项链", "添加\n戒指"]
	var equip_slot_keys := ["weapon", "helmet", "chest", "gloves", "pants", "boots", "necklace", "ring"]
	if equip_grid:
		for c in equip_grid.get_children():
			c.queue_free()
		var role_equips: Dictionary = _role_equips.get(rid, {}) if _role_equips.get(rid, null) is Dictionary else {}
		# 通过装备ID统计套装数量
		var suit_counts: Dictionary = {}
		for sk in role_equips.keys():
			var inv_idx: int = int(role_equips[sk])
			if inv_idx >= 0 and inv_idx < _inventory.size():
				var eid: int = int(_inventory[inv_idx].get("id", 0))
				if _suit_members.has(eid):
					var sn: String = _suit_members[eid]
					suit_counts[sn] = int(suit_counts.get(sn, 0)) + 1
		if equip_lbl and equip_lbl is RichTextLabel:
			var rtl: RichTextLabel = equip_lbl as RichTextLabel
			rtl.add_theme_font_override("normal_font", font)
			rtl.add_theme_font_size_override("normal_font_size", 20)
			rtl.add_theme_color_override("default_color", Color(0.22, 0.13, 0.06, 1))
			var suit_text := "装备"
			var suit_parts: Array = []
			for sn in suit_counts.keys():
				if int(suit_counts[sn]) >= 2:
					suit_parts.append("%s:[color=#2ebf40]%d[/color]" % [sn, suit_counts[sn]])
			if not suit_parts.is_empty():
				suit_text += "  " + " ".join(suit_parts)
			rtl.text = suit_text
		for i in 8:
				var slot := PanelContainer.new()
				var ss := StyleBoxFlat.new()
				ss.set_corner_radius_all(6)
				ss.bg_color = Color(0.08, 0.1, 0.15, 0.25)
				ss.border_width_bottom = 2
				ss.border_width_top = 2
				ss.border_width_left = 2
				ss.border_width_right = 2
				ss.border_color = Color(0.4, 0.65, 0.85, 0.4)
				slot.add_theme_stylebox_override("panel", ss)
				slot.custom_minimum_size = Vector2(72, 72)
				var slot_key: String = equip_slot_keys[i]
				var has_equip := role_equips.has(slot_key)
				var equip_item: Dictionary = {}
				if has_equip:
					var inv_idx: int = int(role_equips[slot_key])
					if inv_idx >= 0 and inv_idx < _inventory.size():
						equip_item = _inventory[inv_idx]
					else:
						has_equip = false
				if has_equip and not equip_item.is_empty():
					var icon_path: String = String(equip_item.get("icon", ""))
					if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
						var icon_container := Control.new()
						icon_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
						slot.add_child(icon_container)
						var icon := TextureRect.new()
						icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
						icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						icon.position = Vector2.ZERO
						icon.size = Vector2(72, 72)
						icon.texture = load(icon_path)
						icon_container.add_child(icon)
						var lv_lbl := Label.new()
						lv_lbl.text = "Lv.%d" % int(equip_item.get("level", 10))
						lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
						lv_lbl.position = Vector2(2, 0)
						lv_lbl.size = Vector2(44, 16)
						var lv_ls := LabelSettings.new()
						lv_ls.font = font
						lv_ls.font_size = 13
						lv_ls.font_color = Color(0.2, 0.9, 0.3)
						lv_ls.outline_size = 2
						lv_ls.outline_color = Color(0, 0, 0, 0.9)
						lv_lbl.label_settings = lv_ls
						icon_container.add_child(lv_lbl)
						var equip_name_lbl := Label.new()
						equip_name_lbl.text = String(equip_item.get("name", ""))
						equip_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						equip_name_lbl.position = Vector2(0, 56)
						equip_name_lbl.size = Vector2(72, 16)
						var equip_name_ls := LabelSettings.new()
						equip_name_ls.font = font
						equip_name_ls.font_size = 13
						equip_name_ls.font_color = Color(0.2, 0.9, 0.3)
						equip_name_ls.outline_size = 2
						equip_name_ls.outline_color = Color(0, 0, 0, 0.9)
						equip_name_lbl.label_settings = equip_name_ls
						icon_container.add_child(equip_name_lbl)
					else:
						var lbl := Label.new()
						lbl.text = equip_slot_names[i]
						lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
						lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
						lbl.label_settings = _make_hero_label_settings(font, 13)
						slot.add_child(lbl)
				else:
					var lbl := Label.new()
					lbl.text = equip_slot_names[i]
					lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
					lbl.label_settings = _make_hero_label_settings(font, 13)
					slot.add_child(lbl)
				var slot_btn := Button.new()
				slot_btn.flat = true
				slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				slot_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				var captured_slot_key: String = equip_slot_keys[i]
				var captured_rid := rid
				var captured_slot_idx := i
				slot_btn.pressed.connect(func():
					var equips: Dictionary = _role_equips.get(captured_rid, {}) if _role_equips.get(captured_rid, null) is Dictionary else {}
					if equips.has(captured_slot_key):
						var inv_idx: int = int(equips[captured_slot_key])
						if inv_idx >= 0 and inv_idx < _inventory.size():
							_show_equipped_item_info(_inventory[inv_idx], captured_rid, captured_slot_key)
							return
					_show_equip_bag_select(captured_rid, captured_slot_key, captured_slot_idx)
				)
				slot.add_child(slot_btn)
				equip_grid.add_child(slot)

	# 技能槽
	var skill_row: GridContainer = _hero_panel_get_node("DetailArea/RightCol/SkillGrid")
	if skill_row:
		for c in skill_row.get_children():
			skill_row.remove_child(c)
			c.queue_free()
		var skills: Array = _role_skills.get(rid, []) if _role_skills.get(rid, null) is Array else []
		var role_data: Dictionary = _roles.get(rid, {})
		var default_sid: int = int(role_data.get("default_skill", 0))
		var total_slots: int = 8
		var unlocked_slots: int = int(_role_stars.get(rid, int(role_data.get("init_star", 1)))) + 1
		for i in total_slots:
			var slot_panel := PanelContainer.new()
			var slot_style := StyleBoxFlat.new()
			slot_style.set_corner_radius_all(6)
			slot_panel.custom_minimum_size = Vector2(72, 72)
			if i < skills.size() and skills[i] is Dictionary:
				var sk = skills[i]
				var sid: int = int(sk.get("id", 0))
				var slv: int = int(_research_levels.get(sid, 1))
				var is_talent: bool = sid == default_sid and sid > 0
				var sk_style := StyleBoxFlat.new()
				sk_style.set_corner_radius_all(6)
				if is_talent:
					sk_style.bg_color = Color(0.15, 0.1, 0.02, 0.4)
					sk_style.border_color = Color(0.9, 0.6, 0.1, 0.8)
				else:
					sk_style.bg_color = Color(0.08, 0.1, 0.15, 0.4)
					sk_style.border_color = Color(0.4, 0.65, 0.85, 0.7)
				sk_style.border_width_bottom = 2
				sk_style.border_width_top = 2
				sk_style.border_width_left = 2
				sk_style.border_width_right = 2
				slot_panel.add_theme_stylebox_override("panel", sk_style)
				var icon_container := Control.new()
				icon_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				slot_panel.add_child(icon_container)
				var icon_rect := TextureRect.new()
				icon_rect.position = Vector2.ZERO
				icon_rect.size = Vector2(72, 72)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				var icon_path := _get_skill_icon_path(rid, sid)
				if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
					icon_rect.texture = load(icon_path)
				icon_container.add_child(icon_rect)
				var lv_badge := Label.new()
				lv_badge.text = "Lv.%d" % slv
				var lv_ls := LabelSettings.new()
				lv_ls.font = font
				lv_ls.font_size = 14
				lv_ls.font_color = Color(0.18, 0.75, 0.25, 1)
				lv_ls.outline_size = 2
				lv_ls.outline_color = Color(0, 0, 0, 0.8)
				lv_badge.label_settings = lv_ls
				lv_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lv_badge.position = Vector2(0, 52)
				lv_badge.size = Vector2(72, 20)
				icon_container.add_child(lv_badge)
				var skill_btn := Button.new()
				skill_btn.flat = true
				skill_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				skill_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				slot_panel.add_child(skill_btn)
				var captured_sid := sid
				var captured_slot_idx := i if not is_talent else -1
				skill_btn.pressed.connect(func(): _show_skill_tip(captured_sid, int(_research_levels.get(captured_sid, 1)), captured_slot_idx))
			elif i < unlocked_slots:
				slot_style.set_corner_radius_all(6)
				slot_style.bg_color = Color(0.08, 0.1, 0.15, 0.25)
				slot_style.border_width_bottom = 2
				slot_style.border_width_top = 2
				slot_style.border_width_left = 2
				slot_style.border_width_right = 2
				slot_style.border_color = Color(0.4, 0.65, 0.85, 0.4)
				slot_panel.add_theme_stylebox_override("panel", slot_style)
				var empty_lbl := Label.new()
				empty_lbl.text = "空"
				empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				empty_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
				empty_lbl.label_settings = _make_hero_label_settings(font, 13)
				slot_panel.add_child(empty_lbl)
				var empty_btn := Button.new()
				empty_btn.flat = true
				empty_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				empty_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				slot_panel.add_child(empty_btn)
				var captured_rid := rid
				var captured_idx := i
				empty_btn.pressed.connect(func(): _show_skill_bag(captured_rid, captured_idx))
			else:
				slot_style.set_corner_radius_all(6)
				slot_style.bg_color = Color(0.08, 0.08, 0.08, 0.3)
				slot_style.border_width_bottom = 2
				slot_style.border_width_top = 2
				slot_style.border_width_left = 2
				slot_style.border_width_right = 2
				slot_style.border_color = Color(0.35, 0.35, 0.35, 0.4)
				slot_panel.add_theme_stylebox_override("panel", slot_style)
				var lock_lbl := Label.new()
				lock_lbl.text = "%d星\n解锁" % i
				lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lock_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
				lock_lbl.label_settings = _make_hero_label_settings(font, 12)
				lock_lbl.modulate = Color(1, 1, 1, 0.5)
				slot_panel.add_child(lock_lbl)
			skill_row.add_child(slot_panel)

func _equip_skill_to_slot(rid: String, slot_idx: int, sid: int) -> void:
	var cur: Array = _role_skills.get(rid, []) if _role_skills.get(rid, null) is Array else []
	if slot_idx < cur.size():
		cur[slot_idx] = {"id": sid, "level": 1}
	elif slot_idx == cur.size():
		cur.append({"id": sid, "level": 1})
	else:
		while cur.size() < slot_idx:
			cur.append(null)
		cur.append({"id": sid, "level": 1})
	_role_skills[rid] = cur
	_play_equip_sfx()
	_save_game()
	_show_hero_detail(rid)

func _show_skill_bag(rid: String, slot_idx: int) -> void:
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 128
	add_child(canvas_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(dim)

	var bg_scale := 0.6
	var bg_w := 1360.0 * bg_scale
	var bg_h := 768.0 * bg_scale
	var bg_x := (1280.0 - bg_w) / 2.0
	var bg_y := (720.0 - bg_h) / 2.0
	var bg := TextureRect.new()
	bg.texture = load("res://asserts/image/ui/skill/skill_bag.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.position = Vector2(bg_x, bg_y)
	bg.size = Vector2(bg_w, bg_h)
	canvas_layer.add_child(bg)

	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = Vector2(bg_x + bg_w - 48, bg_y + 8)
	close_btn.size = Vector2(40, 40)
	canvas_layer.add_child(close_btn)
	close_btn.pressed.connect(func():
		remove_child(canvas_layer)
		canvas_layer.queue_free()
	)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			remove_child(canvas_layer)
			canvas_layer.queue_free()
	)

	var owned_ids: Dictionary = {}
	var cur_skills: Array = _role_skills.get(rid, []) if _role_skills.get(rid, null) is Array else []
	for s in cur_skills:
		if s is Dictionary:
			owned_ids[int(s.get("id", 0))] = true

	# 格子区域：原图格子从 (140,112) 到 (1160,656)，列间距20，行间距4
	var grid_x := bg_x + 140.0 * bg_scale
	var grid_y := bg_y + 130.0 * bg_scale
	var grid_w := 1020.0 * bg_scale
	var grid_h := 544.0 * bg_scale
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(grid_x, grid_y)
	scroll.size = Vector2(grid_w, grid_h)
	canvas_layer.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 7
	var h_sep := int(20.0 * bg_scale)
	var v_sep := int(4.0 * bg_scale)
	grid.add_theme_constant_override("h_separation", h_sep)
	grid.add_theme_constant_override("v_separation", v_sep)
	scroll.add_child(grid)

	var slot_w := int(130.0 * bg_scale)
	var slot_h := int(134.0 * bg_scale)
	var all_ids := _load_all_skill_ids()
	for sid in all_ids:
		if int(sid) >= 40000:
			continue
		var lv: int = int(_research_levels.get(sid, 1))
		var key := "%d_%d" % [sid, lv]
		var info: Dictionary = _skill_table.get(key, {})
		var sk_name: String = info.get("name", "")
		var icon_path: String = info.get("icon", "")
		var is_owned: bool = owned_ids.has(int(sid))

		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(slot_w, slot_h)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(slot_w, slot_h)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		if is_owned:
			icon_rect.modulate = Color(0.4, 0.4, 0.4, 0.6)
		wrapper.add_child(icon_rect)

		var name_lbl := Label.new()
		name_lbl.text = "%s Lv.%d" % [sk_name, lv]
		var name_ls := LabelSettings.new()
		name_ls.font = font
		name_ls.font_size = 13
		name_ls.font_color = Color(0.18, 0.75, 0.25, 1) if not is_owned else Color(0.3, 0.5, 0.3, 0.6)
		name_ls.outline_size = 2
		name_ls.outline_color = Color(0, 0, 0, 0.7)
		name_lbl.label_settings = name_ls
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, slot_h - 20)
		name_lbl.size = Vector2(slot_w, 20)
		wrapper.add_child(name_lbl)

		if not is_owned:
			var btn := Button.new()
			btn.flat = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var captured_sid: int = int(sid)
			var captured_canvas := canvas_layer
			var captured_rid := rid
			var captured_slot := slot_idx
			btn.pressed.connect(func():
				_show_skill_tip_with_learn(captured_sid, int(_research_levels.get(captured_sid, 1)), captured_rid, captured_slot, captured_canvas)
			)
			wrapper.add_child(btn)

		grid.add_child(wrapper)

func _show_suit_tip(suit_id: String, suit_name: String, suit_icon: String) -> void:
	var details: Array = _suit_details.get(suit_id, [])
	if details.is_empty():
		return
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 128
	add_child(canvas_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)

	var panel_w := 380.0
	var panel_h := 320.0
	var panel := Panel.new()
	panel.position = Vector2((1280 - panel_w) / 2.0, (720 - panel_h) / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.22, 0.16, 0.08, 0.95)
	ps.set_corner_radius_all(10)
	ps.border_width_bottom = 2
	ps.border_width_top = 2
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_color = Color(0.85, 0.65, 0.2, 0.9)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	# 标题行：图标 + 套装名
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.position = Vector2(16, 12)
	icon_rect.size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not suit_icon.is_empty() and ResourceLoader.exists(suit_icon):
		icon_rect.texture = load(suit_icon)
	panel.add_child(icon_rect)

	var title_lbl := Label.new()
	title_lbl.text = suit_name + " 套装"
	title_lbl.position = Vector2(64, 16)
	title_lbl.size = Vector2(panel_w - 80, 30)
	var title_ls := LabelSettings.new()
	title_ls.font = font
	title_ls.font_size = 22
	title_ls.font_color = Color(1, 0.85, 0.3, 1)
	title_ls.outline_size = 2
	title_ls.outline_color = Color(0, 0, 0, 0.8)
	title_lbl.label_settings = title_ls
	panel.add_child(title_lbl)

	# 进度效果列表
	var y_offset := 60.0
	for d in details:
		var req: int = d["require_count"]
		var desc: String = d["effect_desc"]
		var line_lbl := Label.new()
		line_lbl.text = "%d 件：%s" % [req, desc]
		line_lbl.position = Vector2(24, y_offset)
		line_lbl.size = Vector2(panel_w - 48, 40)
		line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var line_ls := LabelSettings.new()
		line_ls.font = font
		line_ls.font_size = 17
		line_ls.font_color = Color(0.95, 0.92, 0.85, 1)
		line_ls.outline_size = 1
		line_ls.outline_color = Color(0, 0, 0, 0.5)
		line_lbl.label_settings = line_ls
		panel.add_child(line_lbl)
		y_offset += 50.0

	# 右上角红色关闭按钮
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = Vector2(panel_w - 48, 4)
	close_btn.size = Vector2(40, 40)
	panel.add_child(close_btn)
	close_btn.pressed.connect(func():
		remove_child(canvas_layer)
		canvas_layer.queue_free()
	)

	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			remove_child(canvas_layer)
			canvas_layer.queue_free()
	)

func _get_skill_max_level() -> int:
	var research_lv: int = _building_nodes["research"]["level"] if _building_nodes.has("research") else 1
	var lv_data: Dictionary = _get_building_level_data("research", research_lv)
	return int(lv_data.get("skill_max_lv", 5))

func _show_skill_tip(sid: int, slv: int, slot_idx: int = -1) -> void:
	var key := "%d_%d" % [sid, slv]
	var info: Dictionary = _skill_table.get(key, {})
	var sk_name: String = info.get("name", "未知技能")
	var sk_desc: String = info.get("desc", "")
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var next_lv: int = slv + 1
	var upgrade_cost: int = int(_skill_upgrade_cost.get(next_lv, 0))
	var skill_cap: int = _get_skill_max_level()
	var max_lv: bool = not _skill_table.has("%d_%d" % [sid, next_lv]) or slv >= skill_cap

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 128
	add_child(canvas_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)

	var panel := Panel.new()
	var panel_w := 340.0
	var panel_h := 240.0
	panel.position = Vector2((1280 - panel_w) / 2.0, (720 - panel_h) / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.22, 0.16, 0.08, 0.95)
	ps.set_corner_radius_all(10)
	ps.border_width_bottom = 2
	ps.border_width_top = 2
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_color = Color(0.85, 0.65, 0.2, 0.9)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = "%s  Lv.%d" % [sk_name, slv]
	title_lbl.position = Vector2(16, 14)
	title_lbl.size = Vector2(panel_w - 32, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	title_ls.font = font
	title_ls.font_size = 22
	title_ls.font_color = Color(1, 0.85, 0.3, 1)
	title_ls.outline_size = 2
	title_ls.outline_color = Color(0, 0, 0, 0.8)
	title_lbl.label_settings = title_ls
	panel.add_child(title_lbl)

	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true
	desc_rtl.text = sk_desc
	desc_rtl.position = Vector2(16, 50)
	desc_rtl.size = Vector2(panel_w - 32, 80)
	desc_rtl.fit_content = true
	desc_rtl.scroll_active = false
	desc_rtl.add_theme_font_override("normal_font", font)
	desc_rtl.add_theme_font_size_override("normal_font_size", 18)
	desc_rtl.add_theme_color_override("default_color", Color(0.95, 0.92, 0.85, 1))
	panel.add_child(desc_rtl)

	# 升级费用
	var cost_lbl := Label.new()
	if max_lv:
		if slv >= skill_cap:
			cost_lbl.text = "已达研究院等级上限 (Lv.%d)" % skill_cap
		else:
			cost_lbl.text = "已满级"
	else:
		cost_lbl.text = "升级费用：%d 金币" % upgrade_cost
	cost_lbl.position = Vector2(16, 140)
	cost_lbl.size = Vector2(panel_w - 32, 24)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cost_ls := LabelSettings.new()
	cost_ls.font = font
	cost_ls.font_size = 16
	cost_ls.font_color = Color(1, 0.82, 0.2, 1) if not max_lv else Color(0.6, 0.6, 0.6, 1)
	cost_ls.outline_size = 1
	cost_ls.outline_color = Color(0, 0, 0, 0.6)
	cost_lbl.label_settings = cost_ls
	panel.add_child(cost_lbl)

	# 右上角红色关闭按钮
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = Vector2(panel_w - 48, 4)
	close_btn.size = Vector2(40, 40)
	panel.add_child(close_btn)
	close_btn.pressed.connect(func():
		remove_child(canvas_layer)
		canvas_layer.queue_free()
	)

	# 底部按钮行
	var btn_y := panel_h - 48.0
	if slot_idx >= 0:
		var unequip_btn := Button.new()
		unequip_btn.text = "卸载"
		unequip_btn.position = Vector2(panel_w / 2.0 - 90, btn_y)
		unequip_btn.size = Vector2(80, 34)
		unequip_btn.add_theme_font_override("font", font)
		unequip_btn.add_theme_font_size_override("font_size", 18)
		panel.add_child(unequip_btn)
		var captured_unequip_rid := _hero_panel_rid
		var captured_unequip_slot := slot_idx
		unequip_btn.pressed.connect(func():
			if captured_unequip_rid.is_empty() or captured_unequip_slot < 0:
				return
			var cur: Array = _role_skills.get(captured_unequip_rid, []) if _role_skills.get(captured_unequip_rid, null) is Array else []
			if captured_unequip_slot < cur.size():
				cur[captured_unequip_slot] = null
				_role_skills[captured_unequip_rid] = cur
				_save_game()
				_show_hero_detail(captured_unequip_rid)
			remove_child(canvas_layer)
			canvas_layer.queue_free()
		)

	var upgrade_btn := Button.new()
	upgrade_btn.text = "升级"
	if slot_idx >= 0:
		upgrade_btn.position = Vector2(panel_w / 2.0 + 10, btn_y)
	else:
		upgrade_btn.position = Vector2((panel_w - 80) / 2.0, btn_y)
	upgrade_btn.size = Vector2(80, 34)
	upgrade_btn.add_theme_font_override("font", font)
	upgrade_btn.add_theme_font_size_override("font_size", 18)
	upgrade_btn.disabled = max_lv or _gold < upgrade_cost
	panel.add_child(upgrade_btn)

	var captured_sid: int = sid
	upgrade_btn.pressed.connect(func():
		var cur_lv: int = int(_research_levels.get(captured_sid, 1))
		var nxt: int = cur_lv + 1
		var cap: int = _get_skill_max_level()
		var cost: int = int(_skill_upgrade_cost.get(nxt, 0))
		if cur_lv >= cap:
			return
		if _skill_table.has("%d_%d" % [captured_sid, nxt]) and _gold >= cost:
			_gold -= cost
			_research_levels[captured_sid] = nxt
			_play_skill_up_sfx()
			_save_game()
			_refresh_hud()
			_refresh_skill_display_after_upgrade()
			remove_child(canvas_layer)
			canvas_layer.queue_free()
			_show_skill_tip(captured_sid, nxt, slot_idx)
	)

	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			remove_child(canvas_layer)
			canvas_layer.queue_free()
	)

func _show_skill_tip_with_learn(sid: int, slv: int, rid: String, slot_idx: int, bag_canvas: CanvasLayer) -> void:
	var key := "%d_%d" % [sid, slv]
	var info: Dictionary = _skill_table.get(key, {})
	var sk_name: String = info.get("name", "未知技能")
	var sk_desc: String = info.get("desc", "")
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 129
	add_child(canvas_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)

	var panel_w := 340.0
	var panel_h := 200.0
	var panel := Panel.new()
	panel.position = Vector2((1280 - panel_w) / 2.0, (720 - panel_h) / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.22, 0.16, 0.08, 0.95)
	ps.set_corner_radius_all(10)
	ps.border_width_bottom = 2
	ps.border_width_top = 2
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_color = Color(0.85, 0.65, 0.2, 0.9)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = "%s  Lv.%d" % [sk_name, slv]
	title_lbl.position = Vector2(16, 14)
	title_lbl.size = Vector2(panel_w - 32, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	title_ls.font = font
	title_ls.font_size = 22
	title_ls.font_color = Color(1, 0.85, 0.3, 1)
	title_ls.outline_size = 2
	title_ls.outline_color = Color(0, 0, 0, 0.8)
	title_lbl.label_settings = title_ls
	panel.add_child(title_lbl)

	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true
	desc_rtl.text = sk_desc
	desc_rtl.position = Vector2(16, 50)
	desc_rtl.size = Vector2(panel_w - 32, 80)
	desc_rtl.fit_content = true
	desc_rtl.scroll_active = false
	desc_rtl.add_theme_font_override("normal_font", font)
	desc_rtl.add_theme_font_size_override("normal_font_size", 18)
	desc_rtl.add_theme_color_override("default_color", Color(0.95, 0.92, 0.85, 1))
	panel.add_child(desc_rtl)

	# 右上角关闭按钮
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = Vector2(panel_w - 48, 4)
	close_btn.size = Vector2(40, 40)
	panel.add_child(close_btn)
	close_btn.pressed.connect(func():
		remove_child(canvas_layer)
		canvas_layer.queue_free()
	)

	# 学习按钮
	var learn_btn := Button.new()
	learn_btn.text = "学习"
	learn_btn.position = Vector2((panel_w - 80) / 2.0, panel_h - 48.0)
	learn_btn.size = Vector2(80, 34)
	learn_btn.add_theme_font_override("font", font)
	learn_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(learn_btn)
	learn_btn.pressed.connect(func():
		remove_child(canvas_layer)
		canvas_layer.queue_free()
		remove_child(bag_canvas)
		bag_canvas.queue_free()
		_equip_skill_to_slot(rid, slot_idx, sid)
	)

	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			remove_child(canvas_layer)
			canvas_layer.queue_free()
	)

func _refresh_skill_display_after_upgrade() -> void:
	if _function_panel_node == null or not is_instance_valid(_function_panel_node):
		return
	# 研究院面板：重建 SkillGrid + SuitGrid
	var skill_grid: GridContainer = _function_panel_node.get_node_or_null("SkillScroll/ContentVBox/SkillGrid")
	if skill_grid:
		for c in skill_grid.get_children():
			skill_grid.remove_child(c)
			c.queue_free()
		var suit_grid: GridContainer = _function_panel_node.get_node_or_null("SkillScroll/ContentVBox/SuitGrid")
		if suit_grid:
			for c in suit_grid.get_children():
				suit_grid.remove_child(c)
				c.queue_free()
		_connect_research_panel()
		return
	# 英雄面板：刷新技能栏
	var hero_skill_grid: GridContainer = _hero_panel_get_node("DetailArea/RightCol/SkillGrid")
	if hero_skill_grid and not _hero_panel_rid.is_empty():
		_show_hero_detail(_hero_panel_rid)

func _get_skill_icon_path(rid: String, sid: int) -> String:
	# default skill: per-role icon
	var role_idx: int = int(rid) - 10000
	if sid <= 0:
		return "res://asserts/image/ui/skill/default_%s.png" % rid
	# check if there's a per-role default icon for sid==default_skill
	var rd: Dictionary = _roles.get(rid, {})
	var def_sid: int = int(rd.get("default_skill", 0))
	if sid == def_sid and role_idx >= 1 and role_idx <= 5:
		return "res://asserts/image/ui/skill/default_%s.png" % rid
	# general skill icons by id
	var text := _read_table_text("res://asserts/table/skill.txt")
	if not text.is_empty():
		for line: String in text.split("\n", false):
			var s := line.strip_edges()
			if s.is_empty() or s.begins_with("#"):
				continue
			var parts := s.split("\t")
			if parts.size() >= 7 and int((parts[0] as String).strip_edges()) == sid and int((parts[1] as String).strip_edges()) == 1:
				return String((parts[6] as String).strip_edges())
	return ""

func _hero_rebuild_list_card_stars(rid: String) -> void:
	var vbox := _hero_panel_get_node("HeroList/HeroListVBox")
	if vbox == null:
		return
	var star: int = int(_role_stars.get(rid, 1))
	var star_tex: Texture2D = load(STAR_ICON_PATH)
	for card in vbox.get_children():
		if not card.has_meta("rid") or String(card.get_meta("rid")) != rid:
			continue
		# path: card → hbox → info_vbox → stars_hbox (index 2)
		var hbox: HBoxContainer = card.get_child(0)
		if hbox == null or hbox.get_child_count() < 2:
			return
		var info_vbox: VBoxContainer = hbox.get_child(1)
		if info_vbox == null or info_vbox.get_child_count() < 3:
			return
		var stars_hbox: HBoxContainer = info_vbox.get_child(2)
		if stars_hbox == null:
			return
		for c in stars_hbox.get_children():
			stars_hbox.remove_child(c)
			c.queue_free()
		for _s in maxi(star, 0):
			var sr := TextureRect.new()
			sr.texture = star_tex
			sr.custom_minimum_size = Vector2(14, 14)
			sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stars_hbox.add_child(sr)

func _make_hero_label_settings(font: Font, size: int) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = Color(0.22, 0.13, 0.06, 1)
	ls.outline_size = 1
	ls.outline_color = Color(1, 0.96, 0.85, 0.4)
	return ls

# ─── 酒馆面板 ────────────────────────────────────────────────────────────────

func _tavern_all_hero_ids() -> Array:
	var ids := []
	for rid in _roles.keys():
		if int(rid) >= 10001 and int(rid) <= 19999:
			ids.append(rid)
	return ids

func _tavern_roll_pool() -> void:
	var tavern_lv: int = _building_nodes.get("tavern", {}).get("level", 1)
	var available := _tavern_all_hero_ids()
	available.shuffle()
	_tavern_pool = []
	for i in 3:
		if i < tavern_lv and i < available.size():
			_tavern_pool.append(available[i])
		else:
			_tavern_pool.append("")

func _tavern_panel_node(path: String) -> Node:
	return _function_panel_node.get_node_or_null(path) if _function_panel_node and is_instance_valid(_function_panel_node) else null

func _connect_tavern_panel() -> void:
	if _tavern_pool.is_empty():
		_tavern_roll_pool()
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var coin_tex: Texture2D = load("res://asserts/image/ui/icon_coin.png") if ResourceLoader.exists("res://asserts/image/ui/icon_coin.png") else null
	var tavern_lv: int = _building_nodes.get("tavern", {}).get("level", 1)

	for i in 3:
		var card: Panel = _tavern_panel_node("CardRow/Card%d" % i)
		if card == null:
			continue
		var is_unlocked := tavern_lv >= i + 1
		var overlay: Panel = _tavern_panel_node("CardRow/Card%d/LockedOverlay%d" % [i, i])
		if overlay:
			overlay.visible = not is_unlocked
			var lbl: Label = overlay.get_node_or_null("LockedLbl%d" % i)
			if lbl: lbl.label_settings = _make_hero_label_settings(font, 22)
		# 잠금 시 영웅 콘텐츠 숨기기 (LvLbl은 이미 삭제됨)
		for ctrl_name in ["AvatarRect%d" % i, "NameLbl%d" % i,
				"CostIcon%d" % i, "CostLbl%d" % i, "RecruitBtn%d" % i]:
			var ctrl := _tavern_panel_node("CardRow/Card%d/%s" % [i, ctrl_name])
			if ctrl: ctrl.visible = is_unlocked
		if not is_unlocked:
			continue

		var rid: String = _tavern_pool[i] if i < _tavern_pool.size() else ""
		var avatar_rect: TextureRect  = _tavern_panel_node("CardRow/Card%d/AvatarRect%d" % [i, i])
		var name_lbl: Label           = _tavern_panel_node("CardRow/Card%d/NameLbl%d" % [i, i])
		var cost_icon: TextureRect    = _tavern_panel_node("CardRow/Card%d/CostIcon%d" % [i, i])
		var cost_lbl: Label           = _tavern_panel_node("CardRow/Card%d/CostLbl%d" % [i, i])
		var recruit_btn: Button       = _tavern_panel_node("CardRow/Card%d/RecruitBtn%d" % [i, i])

		if name_lbl: name_lbl.label_settings = _make_hero_label_settings(font, 22)
		if cost_lbl: cost_lbl.label_settings = _make_hero_label_settings(font, 22)

		# 清理旧的 NEW/星级标签
		var old_tag: Control = card.get_node_or_null("StarTag%d" % i)
		if old_tag:
			old_tag.queue_free()
		if rid.is_empty():
			if avatar_rect: avatar_rect.texture = null
			if name_lbl: name_lbl.text = "待刷新"
			if cost_icon: cost_icon.visible = false
			if cost_lbl: cost_lbl.text = ""
			if recruit_btn: recruit_btn.visible = false
		else:
			var rd: Dictionary = _roles.get(rid, {})
			var role_idx: int = int(rid) - 10000
			if avatar_rect:
				var ap := "res://asserts/image/role/role%d_avatar.png" % role_idx
				avatar_rect.texture = load(ap) if ResourceLoader.exists(ap) else null
			if name_lbl: name_lbl.text = String(rd.get("name", rid))
			var is_owned := _owned_role_ids.has(rid)
			var tag_ls := LabelSettings.new()
			tag_ls.font = font
			tag_ls.font_size = 22
			tag_ls.font_color = Color(0.2, 0.9, 0.3)
			tag_ls.outline_size = 3
			tag_ls.outline_color = Color(0, 0, 0, 0.9)
			if not is_owned:
				# 头像下半部分显示"新角色"
				var tag_lbl := Label.new()
				tag_lbl.name = "StarTag%d" % i
				tag_lbl.text = "新角色"
				tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tag_lbl.position = Vector2(8, 135)
				tag_lbl.size = Vector2(244, 28)
				tag_lbl.label_settings = tag_ls
				card.add_child(tag_lbl)
			else:
				# 角色名右边显示"+1星"
				var star_tag := Label.new()
				star_tag.name = "StarTag%d" % i
				star_tag.text = "+1星"
				star_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				star_tag.position = Vector2(8, 172)
				star_tag.size = Vector2(244, 24)
				star_tag.label_settings = tag_ls
				card.add_child(star_tag)
			if cost_icon:
				cost_icon.texture = coin_tex
				cost_icon.visible = true
			var recruit_cost: int = _tavern_recruit_cost(rid)
			if cost_lbl:
					cost_lbl.text = str(recruit_cost)
					if _gold < recruit_cost:
						cost_lbl.modulate = Color(0.85, 0.15, 0.15)
					else:
						cost_lbl.modulate = Color(0.18, 0.75, 0.25)
			if recruit_btn:
				recruit_btn.visible = true
				recruit_btn.text = "招募"
				recruit_btn.disabled = _gold < recruit_cost
				_style_tower_btn(recruit_btn, Color(0.55, 0.22, 0.06), Color(0.90, 0.45, 0.15), Color(1.0, 0.88, 0.55))
				var captured_rid := rid
				var captured_i := i
				recruit_btn.pressed.connect(func() -> void:
					_tavern_recruit(captured_rid, captured_i))

	var cost_row_icon: TextureRect = _tavern_panel_node("BottomRow/RefreshCostRow/RefreshCostIcon")
	var cost_row_lbl: Label        = _tavern_panel_node("BottomRow/RefreshCostRow/RefreshCostLbl")
	var refresh_btn: Button        = _tavern_panel_node("BottomRow/RefreshBtn")
	var auto_lbl: Label            = _tavern_panel_node("BottomRow/AutoRefreshLbl")
	if cost_row_icon and coin_tex: cost_row_icon.texture = coin_tex
	if cost_row_lbl:
		var cost_ls := _make_hero_label_settings(font, 22)
		if _gold < TAVERN_REFRESH_COST:
			cost_ls.font_color = Color(0.85, 0.15, 0.15)
		else:
			cost_ls.font_color = Color(0.18, 0.75, 0.25)
		cost_row_lbl.label_settings = cost_ls
		cost_row_lbl.text = "刷新消耗：%d" % TAVERN_REFRESH_COST
	if auto_lbl: auto_lbl.label_settings = _make_hero_label_settings(font, 22)
	if refresh_btn:
		refresh_btn.text = "刷新"
		refresh_btn.disabled = _gold < TAVERN_REFRESH_COST
		_style_tower_btn(refresh_btn, Color(0.15, 0.35, 0.58), Color(0.25, 0.55, 0.85), Color(0.75, 0.92, 1.0))
		refresh_btn.pressed.connect(func() -> void: _tavern_manual_refresh())
	_tavern_update_auto_label()

func _tavern_recruit_cost(rid: String) -> int:
	var star: int = int(_role_stars.get(rid, 1))
	var idx: int = clampi(star - 1, 0, TAVERN_RECRUIT_COSTS.size() - 1)
	return TAVERN_RECRUIT_COSTS[idx]

func _tavern_recruit(rid: String, slot_idx: int) -> void:
	var cost: int = _tavern_recruit_cost(rid)
	if _gold < cost:
		return
	_gold -= cost
	var is_new := not _owned_role_ids.has(rid)
	if is_new:
		_owned_role_ids.append(rid)
		_ensure_role_data(rid)
	else:
		var max_star: int = GlobalConfig.get_int("max_star_level", 6)
		var cur_star: int = int(_role_stars.get(rid, 1))
		if cur_star < max_star:
			_role_stars[rid] = cur_star + 1
			_refresh_role_label_for(rid)
	if slot_idx < _tavern_pool.size():
		_tavern_pool[slot_idx] = ""
	_refresh_hud()
	_save_game()
	if is_new and _expedition_team_ids.size() < MAX_EXPEDITION_SIZE:
		_expedition_team_ids.append(rid)
		_clear_team_nodes()
		_place_expedition_team()
	_tavern_reload_panel()
	_tavern_reload_panel()

func _tavern_manual_refresh() -> void:
	if _gold < TAVERN_REFRESH_COST:
		return
	_gold -= TAVERN_REFRESH_COST
	_refresh_hud()
	_tavern_roll_pool()
	_save_game()
	_tavern_reload_panel()

func _tavern_reload_panel() -> void:
	_unload_function_panel()
	_function_panel_node = load("res://scenes/building_panels/TavernPanel.tscn").instantiate()
	_function_area.add_child(_function_panel_node)
	if _function_panel_node is Control:
		(_function_panel_node as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_connect_tavern_panel()

func _tavern_update_auto_label() -> void:
	if not (_function_panel_node and is_instance_valid(_function_panel_node) and _panel_key == "tavern"):
		return
	var auto_lbl: Label = _tavern_panel_node("BottomRow/AutoRefreshLbl")
	if auto_lbl == null:
		return
	var remaining := maxf(0.0, TAVERN_AUTO_REFRESH_INTERVAL - _tavern_auto_timer)
	var h := int(remaining) / 3600
	var m := (int(remaining) % 3600) / 60
	var s := int(remaining) % 60
	auto_lbl.text = "下次自动刷新：%02d:%02d:%02d" % [h, m, s]

func _tick_tavern_auto_refresh(delta: float) -> void:
	_tavern_auto_timer += delta
	if _tavern_auto_timer >= TAVERN_AUTO_REFRESH_INTERVAL:
		_tavern_auto_timer = 0.0
		_tavern_free_refreshes = mini(_tavern_free_refreshes + 1, TAVERN_MAX_FREE_REFRESHES)
		_tavern_roll_pool()
		_save_game()
		if _panel_key == "tavern" and _panel_visible:
			_tavern_reload_panel()
	_tavern_update_auto_label()

# ─── 资源兑换面板（伐木场 / 矿石场）───────────────────────────────────────────

func _connect_exchange_panel(key: String) -> void:
	if not (_function_panel_node and is_instance_valid(_function_panel_node)):
		return
	var lv: int = _building_nodes[key]["level"]
	var amount: int = EXCHANGE_AMOUNTS[lv]
	var gain: int = amount / 2
	var res_name: String = "木材" if key == "lumberyard" else "矿石"
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var cost_lbl1: Label = _function_panel_node.get_node_or_null("ExchangeRows/Row1/CostLbl1")
	var gain_lbl1: Label = _function_panel_node.get_node_or_null("ExchangeRows/Row1/GainLbl1")
	var btn1: Button = _function_panel_node.get_node_or_null("ExchangeRows/Row1/ExchangeBtn1")
	var cost_lbl2: Label = _function_panel_node.get_node_or_null("ExchangeRows/Row2/CostLbl2")
	var gain_lbl2: Label = _function_panel_node.get_node_or_null("ExchangeRows/Row2/GainLbl2")
	var btn2: Button = _function_panel_node.get_node_or_null("ExchangeRows/Row2/ExchangeBtn2")
	var section_lbl: Label = _function_panel_node.get_node_or_null("SectionLbl")
	if section_lbl:
		section_lbl.add_theme_font_override("font", font)
		section_lbl.add_theme_font_size_override("font_size", 22)
	for lbl in [cost_lbl1, gain_lbl1, cost_lbl2, gain_lbl2]:
		if lbl:
			lbl.add_theme_font_override("font", font)
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(0.18, 0.75, 0.25))
	if cost_lbl1:
		cost_lbl1.text = "%d %s " % [amount, res_name]
	if gain_lbl1:
		gain_lbl1.text = " %d 金币" % gain
	if cost_lbl2:
		cost_lbl2.text = "%d 金币 " % amount
	if gain_lbl2:
		gain_lbl2.text = " %d %s" % [gain, res_name]
	var has_res: bool = (_wood >= amount) if key == "lumberyard" else (_ore >= amount)
	var has_gold: bool = _gold >= amount
	if btn1:
		_style_tower_btn(btn1, Color(0.55, 0.22, 0.06), Color(0.90, 0.45, 0.15), Color(1.0, 0.88, 0.55))
		btn1.disabled = not has_res
		btn1.pressed.connect(_on_exchange_pressed.bind(key, "res_to_gold"))
	if btn2:
		_style_tower_btn(btn2, Color(0.15, 0.35, 0.58), Color(0.25, 0.55, 0.85), Color(0.75, 0.92, 1.0))
		btn2.disabled = not has_gold
		btn2.pressed.connect(_on_exchange_pressed.bind(key, "gold_to_res"))
	var boost_btn: Button = _function_panel_node.get_node_or_null("ExchangeRows/BoostRow/BoostBtnWrap/BoostBtn")
	var boost_lbl: Label = _function_panel_node.get_node_or_null("ExchangeRows/BoostRow/BoostChargeLbl")
	if boost_lbl:
		boost_lbl.add_theme_font_override("font", font)
		boost_lbl.add_theme_font_size_override("font_size", 20)
		var charge_color: Color = Color(0.18, 0.75, 0.25) if _ad_boost_charges > 0 else Color(0.85, 0.15, 0.15)
		boost_lbl.add_theme_color_override("font_color", charge_color)
		boost_lbl.text = "可用次数:%d 观看广告可增加次数" % _ad_boost_charges
	if boost_btn:
		_style_tower_btn(boost_btn, Color(0.55, 0.22, 0.06), Color(0.90, 0.45, 0.15), Color(1.0, 0.88, 0.55))
		boost_btn.disabled = _ad_boost_charges <= 0
		boost_btn.pressed.connect(_on_boost_pressed.bind(key))

func _on_boost_pressed(key: String) -> void:
	if _ad_boost_charges <= 0:
		return
	_ad_boost_charges -= 1
	var lv: int = _building_nodes[key]["level"]
	var ticks: int = int(7200.0 / PRODUCE_INTERVAL)
	var amount: int = PRODUCE_RATES[lv - 1] * ticks
	if key == "lumberyard":
		_wood += amount
		_spawn_float_text(key, amount, "wood")
	else:
		_ore += amount
		_spawn_float_text(key, amount, "ore")
	_refresh_hud()
	_save_game()
	_refresh_exchange_boost(key)

func _refresh_exchange_boost(key: String) -> void:
	if not (_function_panel_node and is_instance_valid(_function_panel_node)):
		return
	var boost_btn: Button = _function_panel_node.get_node_or_null("ExchangeRows/BoostRow/BoostBtnWrap/BoostBtn")
	var boost_lbl: Label = _function_panel_node.get_node_or_null("ExchangeRows/BoostRow/BoostChargeLbl")
	if boost_btn:
		boost_btn.disabled = _ad_boost_charges <= 0
	if boost_lbl:
		boost_lbl.text = "可用次数:%d 观看广告可增加次数" % _ad_boost_charges

func _on_exchange_pressed(key: String, direction: String) -> void:
	var lv: int = _building_nodes[key]["level"]
	var amount: int = EXCHANGE_AMOUNTS[lv]
	var gain: int = amount / 2
	if direction == "res_to_gold":
		if key == "lumberyard":
			if _wood < amount:
				return
			_wood -= amount
		else:
			if _ore < amount:
				return
			_ore -= amount
		_gold += gain
		_spawn_float_text(key, gain, "gold")
	else:
		if _gold < amount:
			return
		_gold -= amount
		if key == "lumberyard":
			_wood += gain
			_spawn_float_text(key, gain, "wood")
		else:
			_ore += gain
			_spawn_float_text(key, gain, "ore")
	_refresh_hud()
	_save_game()
	_refresh_exchange_buttons(key)

func _refresh_exchange_buttons(key: String) -> void:
	if not (_function_panel_node and is_instance_valid(_function_panel_node)):
		return
	var lv: int = _building_nodes[key]["level"]
	var amount: int = EXCHANGE_AMOUNTS[lv]
	var btn1: Button = _function_panel_node.get_node_or_null("ExchangeRows/Row1/ExchangeBtn1")
	var btn2: Button = _function_panel_node.get_node_or_null("ExchangeRows/Row2/ExchangeBtn2")
	var has_res: bool = (_wood >= amount) if key == "lumberyard" else (_ore >= amount)
	var has_gold: bool = _gold >= amount
	if btn1:
		btn1.disabled = not has_res
	if btn2:
		btn2.disabled = not has_gold

func _connect_tower_buttons() -> void:
	_build_level_track()
	_refresh_level_info()
	var exp_btn: Button = _function_panel_node.get_node_or_null("ActionRow/ExpeditionBtn")
	if exp_btn:
		_style_tower_btn(exp_btn, Color(0.55, 0.22, 0.06), Color(0.90, 0.45, 0.15), Color(1.0, 0.88, 0.55))
		exp_btn.pressed.connect(func() -> void:
			GlobalConfig.set_runtime("scene_mode", "battle")
			GlobalConfig.set_runtime("formation_id", _formation_id)
			GlobalConfig.set_runtime("level_id", _next_level_id())
			var scene := load(BATTLE_SCENE_PATH) as PackedScene
			SceneTransition.change_to(scene)
		)
	var form_btn: Button = _function_panel_node.get_node_or_null("ActionRow/FormationBtn")
	if form_btn:
		_style_tower_btn(form_btn, Color(0.15, 0.35, 0.58), Color(0.25, 0.55, 0.85), Color(0.75, 0.92, 1.0))
		var action_row := _function_panel_node.get_node_or_null("ActionRow") as HBoxContainer
		if action_row:
			action_row.add_theme_constant_override("separation", 40)
		form_btn.text = _formation_name
		form_btn.pressed.connect(func() -> void:
			GlobalConfig.set_runtime("scene_mode", "formation")
			GlobalConfig.set_runtime("formation_id", _formation_id)
			var scene := load(BATTLE_SCENE_PATH) as PackedScene
			SceneTransition.change_to(scene)
		)

func _style_tower_btn(btn: Button, bg_color: Color, border_color: Color, text_color: Color) -> void:
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(12)
	normal.border_width_top    = 2
	normal.border_width_right  = 2
	normal.border_width_bottom = 4
	normal.border_width_left   = 2
	normal.border_color = border_color
	normal.shadow_color  = Color(0, 0, 0, 0.5)
	normal.shadow_size   = 6
	normal.shadow_offset = Vector2(0, 3)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(12)
	hover.border_width_top    = 2
	hover.border_width_right  = 2
	hover.border_width_bottom = 4
	hover.border_width_left   = 2
	hover.border_color = border_color.lightened(0.2)
	hover.shadow_color  = Color(0, 0, 0, 0.5)
	hover.shadow_size   = 8
	hover.shadow_offset = Vector2(0, 3)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.15)
	pressed.set_corner_radius_all(12)
	pressed.border_width_top    = 2
	pressed.border_width_right  = 2
	pressed.border_width_bottom = 2
	pressed.border_width_left   = 2
	pressed.border_color = border_color
	pressed.shadow_color  = Color(0, 0, 0, 0.3)
	pressed.shadow_size   = 3
	pressed.shadow_offset = Vector2(0, 1)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = bg_color.darkened(0.4)
	disabled.set_corner_radius_all(12)
	disabled.border_width_top    = 2
	disabled.border_width_right  = 2
	disabled.border_width_bottom = 4
	disabled.border_width_left   = 2
	disabled.border_color = border_color.darkened(0.4)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus",    normal)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color",          text_color)
	btn.add_theme_color_override("font_hover_color",    text_color.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color",  text_color.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", text_color.darkened(0.3))
	btn.add_theme_color_override("font_outline_color",  Color(0, 0, 0, 0.8))
	btn.add_theme_constant_override("outline_size", 3)

func _show_equip_bag() -> void:
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 30
	add_child(canvas_layer)
	var panel: Control = load("res://scenes/EquipBagPanel.tscn").instantiate()
	canvas_layer.add_child(panel)
	var close_btn: TextureButton = panel.get_node("CloseBtn")
	close_btn.pressed.connect(func():
		canvas_layer.queue_free()
	)
	var grid_node: Control = panel.get_node("GridContainer")
	var tab_highlight: Panel = panel.get_node("TabHighlight")
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(1.0, 0.85, 0.4, 0.2)
	hl_style.set_corner_radius_all(4)
	hl_style.border_width_top = 2
	hl_style.border_width_bottom = 2
	hl_style.border_width_left = 2
	hl_style.border_width_right = 2
	hl_style.border_color = Color(1.0, 0.75, 0.2, 0.9)
	tab_highlight.add_theme_stylebox_override("panel", hl_style)
	var tab_slots := ["weapon", "helmet", "chest", "pants", "boots", "gloves", "necklace", "ring"]
	var tab_names := ["TabWeapon", "TabHelmet", "TabChest", "TabPants", "TabBoots", "TabGloves", "TabNecklace", "TabRing"]
	var grid_cols := 8
	var slot_size := 50.0
	var slot_gap := (grid_node.size.x - slot_size * grid_cols) / maxf(grid_cols - 1, 1)
	# 右上角数量标签
	var count_lbl := Label.new()
	count_lbl.size = Vector2(120.0, 24.0)
	count_lbl.position = Vector2(grid_node.position.x + grid_node.size.x - 120, grid_node.position.y - 26)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cls := LabelSettings.new()
	cls.font = font
	cls.font_size = 14
	cls.font_color = Color(0.2, 0.9, 0.3)
	cls.outline_size = 2
	cls.outline_color = Color(0, 0, 0, 0.8)
	count_lbl.label_settings = cls
	panel.add_child(count_lbl)
	var state := {"tab": "weapon"}
	var grid_fn := [null]
	var _refresh_grid := func(filter: String) -> void:
		var count: int = 0
		for it in _inventory:
			if String(it.get("slot", "")) == filter:
				count += 1
		count_lbl.text = "%d / 32" % count
		for c in grid_node.get_children():
			c.queue_free()
		var filtered: Array = []
		for item in _inventory:
			if String(item.get("slot", "")) == filter:
				filtered.append(item)
		if not filtered.is_empty():
			for i in filtered.size():
				var item2: Dictionary = filtered[i]
				var col: int = i % grid_cols
				var row: int = i / grid_cols
				var sx: float = col * (slot_size + slot_gap)
				var sy: float = row * (slot_size + slot_gap)
				var icon_path: String = String(item2.get("icon", ""))
				if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
					var icon := TextureRect.new()
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.custom_minimum_size = Vector2(slot_size, slot_size)
					icon.size = Vector2(slot_size, slot_size)
					icon.position = Vector2(sx, sy)
					icon.texture = load(icon_path)
					icon.mouse_filter = Control.MOUSE_FILTER_STOP
					icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					icon.gui_input.connect(_on_bag_item_click.bind(item2, canvas_layer, grid_fn, state))
					grid_node.add_child(icon)
				var lv_lbl := Label.new()
				lv_lbl.text = "Lv.%d" % int(item2.get("level", 10))
				lv_lbl.size = Vector2(34, 16.0)
				lv_lbl.position = Vector2(sx + 1, sy)
				lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				var lv_ls := LabelSettings.new()
				lv_ls.font = font
				lv_ls.font_size = 12
				lv_ls.font_color = Color(0.2, 0.9, 0.3)
				lv_ls.outline_size = 2
				lv_ls.outline_color = Color(0, 0, 0, 0.9)
				lv_lbl.label_settings = lv_ls
				grid_node.add_child(lv_lbl)
				var name_lbl := Label.new()
				name_lbl.text = String(item2.get("name", ""))
				name_lbl.size = Vector2(slot_size, 16.0)
				name_lbl.position = Vector2(sx, sy + slot_size - 15.0)
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.clip_text = true
				var name_ls := LabelSettings.new()
				name_ls.font = font
				name_ls.font_size = 12
				name_ls.font_color = Color(0.2, 0.9, 0.3)
				name_ls.outline_size = 2
				name_ls.outline_color = Color(0, 0, 0, 0.9)
				name_lbl.label_settings = name_ls
				grid_node.add_child(name_lbl)
				if _is_item_equipped(item2):
					var worn_lbl := Label.new()
					worn_lbl.text = "穿"
					worn_lbl.size = Vector2(20, 16.0)
					worn_lbl.position = Vector2(sx + slot_size - 20, sy)
					worn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					var worn_ls := LabelSettings.new()
					worn_ls.font = font
					worn_ls.font_size = 12
					worn_ls.font_color = Color(0.2, 0.9, 0.3)
					worn_ls.outline_size = 2
					worn_ls.outline_color = Color(0, 0, 0, 0.9)
					worn_lbl.label_settings = worn_ls
					grid_node.add_child(worn_lbl)
				if item2.get("is_new", false):
					var new_icon := TextureRect.new()
					new_icon.texture = load("res://asserts/image/ui/redpoint.png")
					new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					new_icon.size = Vector2(16, 16)
					new_icon.position = Vector2(sx + slot_size - 16, sy)
					grid_node.add_child(new_icon)
	grid_fn[0] = _refresh_grid
	var tab_new_lbls: Array = []
	for ti in tab_slots.size():
		var tab_btn: Button = panel.get_node(tab_names[ti])
		var captured_key: String = tab_slots[ti]
		var tab_new := TextureRect.new()
		tab_new.texture = load("res://asserts/image/ui/redpoint.png")
		tab_new.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tab_new.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tab_new.size = Vector2(16, 16)
		tab_new.position = Vector2(tab_btn.position.x + tab_btn.size.x - 14, tab_btn.position.y - 2)
		tab_new.visible = _has_new_items(captured_key)
		panel.add_child(tab_new)
		tab_new_lbls.append(tab_new)
		tab_btn.pressed.connect(func() -> void:
			state["tab"] = captured_key
			tab_highlight.position = tab_btn.position
			tab_highlight.size = tab_btn.size
			_refresh_grid.call(captured_key)
			_refresh_bag_tab_badges(tab_slots, tab_new_lbls)
		)
	state["tab_slots"] = tab_slots
	state["tab_new_lbls"] = tab_new_lbls
	# 一键售出按钮
	var sell_btn: Button = panel.get_node("SellBtn")
	sell_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_btn.pressed.connect(func() -> void:
		var cur: String = state["tab"]
		var to_remove: Array = []
		for inv_item in _inventory:
			if String(inv_item.get("slot", "")) == cur and not _is_item_equipped(inv_item):
				to_remove.append(inv_item)
		_show_sell_confirm(to_remove, 0, cur, canvas_layer, _refresh_grid, state)
	)
	_refresh_grid.call("weapon")

func _show_equipped_item_info(item: Dictionary, rid: String, slot_key: String) -> void:
	var vp := get_viewport_rect().size
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 31
	add_child(canvas_layer)
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(container)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(dim)
	var popup_w := 280.0
	var popup_h := 340.0
	var popup := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.12, 0.22, 0.97)
	ps.set_corner_radius_all(12)
	ps.border_width_top = 2
	ps.border_width_bottom = 2
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_color = Color(1.0, 0.65, 0.0, 0.8)
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 8
	popup.add_theme_stylebox_override("panel", ps)
	popup.size = Vector2(popup_w, popup_h)
	popup.position = (vp - Vector2(popup_w, popup_h)) * 0.5
	container.add_child(popup)
	# 装备图标
	var icon_path: String = String(item.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.size = Vector2(64, 64)
		icon_rect.position = popup.position + Vector2((popup_w - 64) * 0.5, 8)
		icon_rect.texture = load(icon_path)
		container.add_child(icon_rect)
	# 装备名
	var name_lbl := Label.new()
	name_lbl.text = String(item.get("name", ""))
	name_lbl.size = Vector2(popup_w, 36.0)
	name_lbl.position = popup.position + Vector2(0, 72)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nls := LabelSettings.new()
	nls.font = font
	nls.font_size = 22
	nls.font_color = Color(1.0, 0.65, 0.0)
	nls.outline_size = 2
	nls.outline_color = Color(0, 0, 0, 1.0)
	name_lbl.label_settings = nls
	container.add_child(name_lbl)
	# 属性信息
	var slot_names := {"weapon": "武器", "helmet": "头盔", "chest": "胸甲", "gloves": "手套", "pants": "裤子", "boots": "鞋子", "necklace": "项链", "ring": "戒指"}
	var slot_cn: String = slot_names.get(String(item.get("slot", "")), "")
	var info_text := "Lv.%d  [%s]\n" % [int(item.get("level", 10)), slot_cn]
	var attrs := [["攻击", "atk"], ["防御", "def"], ["生命", "hp"], ["速度", "speed"], ["暴击", "crit"], ["闪避", "dodge"]]
	for a in attrs:
		var val: int = int(item.get(a[1], 0))
		if val > 0:
			info_text += "%s [color=#2ebf40]+%d[/color]\n" % [a[0], val]
	var info_lbl := RichTextLabel.new()
	info_lbl.bbcode_enabled = true
	info_lbl.text = info_text
	info_lbl.fit_content = true
	info_lbl.scroll_active = false
	info_lbl.size = Vector2(popup_w - 40, popup_h - 190)
	info_lbl.position = popup.position + Vector2(20, 110)
	info_lbl.add_theme_font_override("normal_font", font)
	info_lbl.add_theme_font_size_override("normal_font_size", 18)
	info_lbl.add_theme_color_override("default_color", Color(0.9, 0.92, 0.85))
	container.add_child(info_lbl)
	# 卸载按钮
	var unequip_btn := Button.new()
	unequip_btn.text = "卸载"
	unequip_btn.custom_minimum_size = Vector2(100, 38)
	unequip_btn.size = Vector2(100, 38)
	unequip_btn.position = popup.position + Vector2((popup_w - 100) * 0.5, popup_h - 52)
	unequip_btn.add_theme_font_override("font", font)
	unequip_btn.add_theme_font_size_override("font_size", 18)
	unequip_btn.pressed.connect(func() -> void:
		if _role_equips.has(rid) and (_role_equips[rid] as Dictionary).has(slot_key):
			(_role_equips[rid] as Dictionary).erase(slot_key)
		_play_equip_sfx()
		_save_game()
		canvas_layer.queue_free()
		_show_hero_detail(rid)
	)
	container.add_child(unequip_btn)
	# 关闭按钮
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = popup.position + Vector2(popup_w - 48, 4)
	close_btn.size = Vector2(40, 40)
	close_btn.pressed.connect(func():
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		canvas_layer.call_deferred("queue_free")
	)
	container.add_child(close_btn)

func _show_equip_bag_select(rid: String, slot_key: String, slot_idx: int) -> void:
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 30
	add_child(canvas_layer)
	var panel: Control = load("res://scenes/EquipBagPanel.tscn").instantiate()
	canvas_layer.add_child(panel)
	var close_btn: TextureButton = panel.get_node("CloseBtn")
	close_btn.pressed.connect(func():
		canvas_layer.queue_free()
	)
	var grid_node: Control = panel.get_node("GridContainer")
	var tab_highlight: Panel = panel.get_node("TabHighlight")
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(1.0, 0.85, 0.4, 0.2)
	hl_style.set_corner_radius_all(4)
	hl_style.border_width_top = 2
	hl_style.border_width_bottom = 2
	hl_style.border_width_left = 2
	hl_style.border_width_right = 2
	hl_style.border_color = Color(1.0, 0.75, 0.2, 0.9)
	tab_highlight.add_theme_stylebox_override("panel", hl_style)
	var tab_slots := ["weapon", "helmet", "chest", "pants", "boots", "gloves", "necklace", "ring"]
	var tab_names := ["TabWeapon", "TabHelmet", "TabChest", "TabPants", "TabBoots", "TabGloves", "TabNecklace", "TabRing"]
	var grid_cols := 8
	var slot_size := 50.0
	var slot_gap := (grid_node.size.x - slot_size * grid_cols) / maxf(grid_cols - 1, 1)
	# 右上角数量标签
	var count_lbl := Label.new()
	count_lbl.size = Vector2(120.0, 24.0)
	count_lbl.position = Vector2(grid_node.position.x + grid_node.size.x - 120, grid_node.position.y - 26)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cls := LabelSettings.new()
	cls.font = font
	cls.font_size = 14
	cls.font_color = Color(0.2, 0.9, 0.3)
	cls.outline_size = 2
	cls.outline_color = Color(0, 0, 0, 0.8)
	count_lbl.label_settings = cls
	panel.add_child(count_lbl)
	# 刷新网格
	var _refresh_grid := func(filter: String) -> void:
		var count: int = 0
		for it in _inventory:
			if String(it.get("slot", "")) == filter:
				count += 1
		count_lbl.text = "%d / 32" % count
		for c in grid_node.get_children():
			c.queue_free()
		var filtered: Array = []
		for item in _inventory:
			if String(item.get("slot", "")) == filter:
				filtered.append(item)
		if not filtered.is_empty():
			for i in filtered.size():
				var item2: Dictionary = filtered[i]
				var col: int = i % grid_cols
				var row: int = i / grid_cols
				var sx: float = col * (slot_size + slot_gap)
				var sy: float = row * (slot_size + slot_gap)
				var icon_path: String = String(item2.get("icon", ""))
				if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
					var icon := TextureRect.new()
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.custom_minimum_size = Vector2(slot_size, slot_size)
					icon.size = Vector2(slot_size, slot_size)
					icon.position = Vector2(sx, sy)
					icon.texture = load(icon_path)
					icon.mouse_filter = Control.MOUSE_FILTER_STOP
					icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					var captured_item := item2
					icon.gui_input.connect(func(ev: InputEvent) -> void:
						if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
							_show_equip_confirm(captured_item, rid, slot_key, slot_idx, canvas_layer)
					)
					grid_node.add_child(icon)
				var lv_lbl := Label.new()
				lv_lbl.text = "Lv.%d" % int(item2.get("level", 10))
				lv_lbl.size = Vector2(34, 16.0)
				lv_lbl.position = Vector2(sx + 1, sy)
				lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				var lv_ls := LabelSettings.new()
				lv_ls.font = font
				lv_ls.font_size = 12
				lv_ls.font_color = Color(0.2, 0.9, 0.3)
				lv_ls.outline_size = 2
				lv_ls.outline_color = Color(0, 0, 0, 0.9)
				lv_lbl.label_settings = lv_ls
				grid_node.add_child(lv_lbl)
				var name_lbl := Label.new()
				name_lbl.text = String(item2.get("name", ""))
				name_lbl.size = Vector2(slot_size, 16.0)
				name_lbl.position = Vector2(sx, sy + slot_size - 15.0)
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.clip_text = true
				var name_ls := LabelSettings.new()
				name_ls.font = font
				name_ls.font_size = 12
				name_ls.font_color = Color(0.2, 0.9, 0.3)
				name_ls.outline_size = 2
				name_ls.outline_color = Color(0, 0, 0, 0.9)
				name_lbl.label_settings = name_ls
				grid_node.add_child(name_lbl)
				if _is_item_equipped(item2):
					var worn_lbl := Label.new()
					worn_lbl.text = "穿"
					worn_lbl.size = Vector2(20, 16.0)
					worn_lbl.position = Vector2(sx + slot_size - 20, sy)
					worn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					var worn_ls := LabelSettings.new()
					worn_ls.font = font
					worn_ls.font_size = 12
					worn_ls.font_color = Color(0.2, 0.9, 0.3)
					worn_ls.outline_size = 2
					worn_ls.outline_color = Color(0, 0, 0, 0.9)
					worn_lbl.label_settings = worn_ls
					grid_node.add_child(worn_lbl)
	# 页签按钮 - 点击提示"正在选装中"
	for ti in tab_slots.size():
		var tab_btn: Button = panel.get_node(tab_names[ti])
		tab_btn.pressed.connect(func() -> void:
			_show_toast("正在选装中")
		)
	# 一键售出按钮 - 点击提示"正在选装中"
	var sell_btn: Button = panel.get_node("SellBtn")
	sell_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	sell_btn.pressed.connect(func() -> void:
		_show_toast("正在选装中")
	)
	# 定位高亮到对应页签
	var tab_idx: int = tab_slots.find(slot_key)
	if tab_idx >= 0:
		var target_btn: Button = panel.get_node(tab_names[tab_idx])
		tab_highlight.position = target_btn.position
		tab_highlight.size = target_btn.size
	_refresh_grid.call(slot_key)

func _show_equip_confirm(item: Dictionary, rid: String, slot_key: String, slot_idx: int, bag_layer: CanvasLayer) -> void:
	var vp := get_viewport_rect().size
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 31
	add_child(confirm_layer)
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(container)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(dim)
	var popup_w := 280.0
	var popup_h := 340.0
	var popup := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.12, 0.22, 0.97)
	ps.set_corner_radius_all(12)
	ps.border_width_top = 2
	ps.border_width_bottom = 2
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_color = Color(1.0, 0.65, 0.0, 0.8)
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 8
	popup.add_theme_stylebox_override("panel", ps)
	popup.size = Vector2(popup_w, popup_h)
	popup.position = (vp - Vector2(popup_w, popup_h)) * 0.5
	container.add_child(popup)
	var icon_path: String = String(item.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.size = Vector2(64, 64)
		icon_rect.position = popup.position + Vector2((popup_w - 64) * 0.5, 8)
		icon_rect.texture = load(icon_path)
		container.add_child(icon_rect)
	var name_lbl := Label.new()
	name_lbl.text = String(item.get("name", ""))
	name_lbl.size = Vector2(popup_w, 36.0)
	name_lbl.position = popup.position + Vector2(0, 72)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nls := LabelSettings.new()
	nls.font = font
	nls.font_size = 22
	nls.font_color = Color(1.0, 0.65, 0.0)
	nls.outline_size = 2
	nls.outline_color = Color(0, 0, 0, 1.0)
	name_lbl.label_settings = nls
	container.add_child(name_lbl)
	var slot_names := {"weapon": "武器", "helmet": "头盔", "chest": "胸甲", "gloves": "手套", "pants": "裤子", "boots": "鞋子", "necklace": "项链", "ring": "戒指"}
	var slot_cn: String = slot_names.get(String(item.get("slot", "")), "")
	var info_text := "Lv.%d  [%s]\n" % [int(item.get("level", 10)), slot_cn]
	var attrs := [["攻击", "atk"], ["防御", "def"], ["生命", "hp"], ["速度", "speed"], ["暴击", "crit"], ["闪避", "dodge"]]
	for a in attrs:
		var val: int = int(item.get(a[1], 0))
		if val > 0:
			info_text += "%s [color=#2ebf40]+%d[/color]\n" % [a[0], val]
	var info_lbl := RichTextLabel.new()
	info_lbl.bbcode_enabled = true
	info_lbl.text = info_text
	info_lbl.fit_content = true
	info_lbl.scroll_active = false
	info_lbl.size = Vector2(popup_w - 40, popup_h - 190)
	info_lbl.position = popup.position + Vector2(20, 110)
	info_lbl.add_theme_font_override("normal_font", font)
	info_lbl.add_theme_font_size_override("normal_font_size", 18)
	info_lbl.add_theme_color_override("default_color", Color(0.9, 0.92, 0.85))
	container.add_child(info_lbl)
	# 穿戴按钮
	var equip_btn := Button.new()
	var already_worn := _is_item_equipped(item)
	equip_btn.text = "已穿戴" if already_worn else "穿戴"
	equip_btn.disabled = already_worn
	equip_btn.custom_minimum_size = Vector2(100, 38)
	equip_btn.size = Vector2(100, 38)
	equip_btn.position = popup.position + Vector2((popup_w - 100) * 0.5, popup_h - 52)
	equip_btn.add_theme_font_override("font", font)
	equip_btn.add_theme_font_size_override("font_size", 18)
	equip_btn.pressed.connect(func() -> void:
		_equip_item_to_role(rid, slot_key, slot_idx, item)
		confirm_layer.queue_free()
		bag_layer.queue_free()
	)
	container.add_child(equip_btn)
	# 关闭按钮
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = popup.position + Vector2(popup_w - 48, 4)
	close_btn.size = Vector2(40, 40)
	close_btn.pressed.connect(func():
		confirm_layer.queue_free()
	)
	container.add_child(close_btn)

func _equip_item_to_role(rid: String, slot_key: String, slot_idx: int, item: Dictionary) -> void:
	if not _role_equips.has(rid):
		_role_equips[rid] = {}
	var old_suit_stage: int = _get_suit_active_stages(rid)
	var idx: int = _inventory.find(item)
	if idx >= 0:
		(_role_equips[rid] as Dictionary)[slot_key] = idx
	var new_suit_stage: int = _get_suit_active_stages(rid)
	_play_equip_sfx()
	if new_suit_stage > old_suit_stage:
		_play_skill_up_sfx()
	_save_game()
	_show_hero_detail(rid)

func _show_toast(msg: String) -> void:
	var vp := get_viewport_rect().size
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 50
	add_child(toast_layer)
	var lbl := Label.new()
	lbl.text = msg
	lbl.size = Vector2(300, 40)
	lbl.position = Vector2((vp.x - 300) * 0.5, vp.y * 0.4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = 20
	ls.font_color = Color(1.0, 0.9, 0.5)
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0, 0.9)
	lbl.label_settings = ls
	toast_layer.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.tween_callback(toast_layer.queue_free)

func _is_item_equipped(item: Dictionary) -> bool:
	var idx: int = _inventory.find(item)
	if idx < 0:
		return false
	for rid in _role_equips.keys():
		var slots: Dictionary = _role_equips[rid]
		for slot_key in slots.keys():
			if int(slots[slot_key]) == idx:
				return true
	return false

func _calc_sell_price(item: Dictionary) -> int:
	var lv: int = maxi(1, int(item.get("level", 10)))
	return maxi(1, lv * 2)

func _show_sell_confirm(to_remove: Array, _unused: int, tab: String, parent_ui: CanvasLayer, refresh_fn: Callable, bag_state: Dictionary = {}) -> void:
	var gold_gain: int = 0
	for sell_item in to_remove:
		gold_gain += _calc_sell_price(sell_item)
	var vp := get_viewport_rect().size
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 31
	add_child(confirm_layer)
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(container)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(dim)
	var popup_w := 320.0
	var popup_h := 180.0
	var popup := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.12, 0.22, 0.97)
	ps.set_corner_radius_all(12)
	ps.border_width_top = 2
	ps.border_width_bottom = 2
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_color = Color(0.8, 0.6, 0.2, 0.9)
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 8
	popup.add_theme_stylebox_override("panel", ps)
	popup.size = Vector2(popup_w, popup_h)
	popup.position = (vp - Vector2(popup_w, popup_h)) * 0.5
	container.add_child(popup)
	var msg_lbl := Label.new()
	msg_lbl.text = "出售当前页所有未装备的装备"
	msg_lbl.size = Vector2(popup_w, 30.0)
	msg_lbl.position = popup.position + Vector2(0, 24)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mls := LabelSettings.new()
	mls.font = font
	mls.font_size = 18
	mls.font_color = Color(0.92, 0.9, 0.82)
	mls.outline_size = 2
	mls.outline_color = Color(0, 0, 0, 0.8)
	msg_lbl.label_settings = mls
	container.add_child(msg_lbl)
	var gold_lbl := Label.new()
	gold_lbl.text = "可获得金币: %d" % gold_gain
	gold_lbl.size = Vector2(popup_w, 28.0)
	gold_lbl.position = popup.position + Vector2(0, 62)
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gls := LabelSettings.new()
	gls.font = font
	gls.font_size = 20
	gls.font_color = Color(1.0, 0.85, 0.2)
	gls.outline_size = 2
	gls.outline_color = Color(0, 0, 0, 0.9)
	gold_lbl.label_settings = gls
	container.add_child(gold_lbl)
	# 确认按钮
	var confirm_btn := Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size = Vector2(100, 38)
	confirm_btn.size = Vector2(100, 38)
	confirm_btn.position = popup.position + Vector2(popup_w * 0.25 - 50, popup_h - 56)
	confirm_btn.add_theme_font_override("font", font)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.pressed.connect(func() -> void:
		for item in to_remove:
			_inventory.erase(item)
		_gold += gold_gain
		_play_sell_sfx()
		_refresh_hud()
		_save_game()
		refresh_fn.call(tab)
		_refresh_store_new_badge()
		if bag_state.has("tab_slots") and bag_state.has("tab_new_lbls"):
			_refresh_bag_tab_badges(bag_state["tab_slots"], bag_state["tab_new_lbls"])
		confirm_layer.queue_free()
	)
	container.add_child(confirm_btn)
	# 取消按钮
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 38)
	cancel_btn.size = Vector2(100, 38)
	cancel_btn.position = popup.position + Vector2(popup_w * 0.75 - 50, popup_h - 56)
	cancel_btn.add_theme_font_override("font", font)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(func() -> void:
		confirm_layer.queue_free()
	)
	container.add_child(cancel_btn)

func _on_bag_item_click(event: InputEvent, item: Dictionary, parent_ui: CanvasLayer, grid_fn: Array, state: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if item.get("is_new", false):
		item["is_new"] = false
		_save_game()
		_refresh_store_new_badge()
		if grid_fn[0] is Callable:
			(grid_fn[0] as Callable).call(state["tab"])
		if state.has("tab_slots") and state.has("tab_new_lbls"):
			_refresh_bag_tab_badges(state["tab_slots"], state["tab_new_lbls"])
	var vp := get_viewport_rect().size
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var popup_w := 280.0
	var popup_h := 340.0
	var container := Control.new()
	container.size = vp
	parent_ui.add_child(container)
	var popup := Panel.new()
	var pps := StyleBoxFlat.new()
	pps.bg_color = Color(0.1, 0.12, 0.22, 0.97)
	pps.set_corner_radius_all(12)
	pps.border_width_top = 2
	pps.border_width_bottom = 2
	pps.border_width_left = 2
	pps.border_width_right = 2
	pps.border_color = Color(1.0, 0.65, 0.0, 0.8)
	pps.shadow_color = Color(0, 0, 0, 0.6)
	pps.shadow_size = 8
	popup.add_theme_stylebox_override("panel", pps)
	popup.size = Vector2(popup_w, popup_h)
	popup.position = (vp - Vector2(popup_w, popup_h)) * 0.5
	container.add_child(popup)
	var slot_names := {"weapon": "武器", "helmet": "头盔", "chest": "胸甲", "gloves": "手套", "pants": "裤子", "boots": "鞋子", "necklace": "项链", "ring": "戒指"}
	var slot_cn: String = slot_names.get(String(item.get("slot", "")), "")
	var icon_path: String = String(item.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.size = Vector2(64, 64)
		icon_rect.position = popup.position + Vector2((popup_w - 64) * 0.5, 8)
		icon_rect.texture = load(icon_path)
		container.add_child(icon_rect)
	var name_lbl := Label.new()
	name_lbl.text = String(item.get("name", ""))
	name_lbl.size = Vector2(popup_w, 36.0)
	name_lbl.position = popup.position + Vector2(0, 72)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nls := LabelSettings.new()
	nls.font = font
	nls.font_size = 22
	nls.font_color = Color(1.0, 0.65, 0.0)
	nls.outline_size = 2
	nls.outline_color = Color(0, 0, 0, 1.0)
	name_lbl.label_settings = nls
	container.add_child(name_lbl)
	var info_text := "Lv.%d  [%s]\n" % [int(item.get("level", 10)), slot_cn]
	var attrs := [["攻击", "atk"], ["防御", "def"], ["生命", "hp"], ["速度", "speed"], ["暴击", "crit"], ["闪避", "dodge"]]
	for a in attrs:
		var val: int = int(item.get(a[1], 0))
		if val > 0:
			info_text += "%s [color=#2ebf40]+%d[/color]\n" % [a[0], val]
	var info_lbl := RichTextLabel.new()
	info_lbl.bbcode_enabled = true
	info_lbl.text = info_text
	info_lbl.fit_content = true
	info_lbl.scroll_active = false
	info_lbl.size = Vector2(popup_w - 40, popup_h - 150)
	info_lbl.position = popup.position + Vector2(20, 110)
	info_lbl.add_theme_font_override("normal_font", font)
	info_lbl.add_theme_font_size_override("normal_font_size", 18)
	info_lbl.add_theme_color_override("default_color", Color(0.9, 0.92, 0.85))
	container.add_child(info_lbl)
	# 售出按钮
	var sell_price: int = _calc_sell_price(item)
	var sell_btn := Button.new()
	sell_btn.custom_minimum_size = Vector2(120, 38)
	sell_btn.size = Vector2(120, 38)
	sell_btn.position = popup.position + Vector2((popup_w - 120) * 0.5, popup_h - 52)
	sell_btn.add_theme_font_override("font", font)
	sell_btn.add_theme_font_size_override("font_size", 16)
	if _is_item_equipped(item):
		sell_btn.text = "已装备"
		sell_btn.disabled = true
	else:
		sell_btn.text = "售出 +%d金" % sell_price
		sell_btn.pressed.connect(func() -> void:
			_inventory.erase(item)
			_gold += sell_price
			_play_sell_sfx()
			_refresh_hud()
			_save_game()
			container.queue_free()
			if grid_fn[0] is Callable:
				(grid_fn[0] as Callable).call(state["tab"])
		)
	container.add_child(sell_btn)
	# 关闭按钮
	var close_btn := TextureButton.new()
	close_btn.texture_normal = load("res://asserts/image/ui/ui_close.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.position = popup.position + Vector2(popup_w - 48, 4)
	close_btn.size = Vector2(40, 40)
	close_btn.pressed.connect(func():
		container.queue_free()
	)
	container.add_child(close_btn)

const LEVEL_TRACK_NODE_H  := 116.0  # 节点图片显示高度（含底部名字区域）
const LEVEL_TRACK_LINE_H  := 60.0   # 连接线显示高度（同行垂直居中）
const LEVEL_TRACK_SHOW    := 5      # 轨道显示几个节点
const LEVEL_TRACK_CURRENT := 2      # 当前节点固定在第几位（0-based），后续不足时右移

const LEVEL_NODE_IMG := {
	"finished": "res://asserts/image/building/building_tower_panel/finished.png",
	"current":  "res://asserts/image/building/building_tower_panel/current.png",
	"locked":   "res://asserts/image/building/building_tower_panel/locked.png",
	"line":     "res://asserts/image/building/building_tower_panel/line.png",
}

func _build_level_track() -> void:
	var track: HBoxContainer = _function_panel_node.get_node_or_null("LevelTrack")
	if track == null:
		return
	for c in track.get_children():
		c.queue_free()

	# 找出当前关卡在 _level_ids 中的索引（第一个 > _cleared_level 的）
	var current_idx := _level_ids.size()  # 默认全部通关
	for i in _level_ids.size():
		if int(_level_ids[i]) > _cleared_level:
			current_idx = i
			break

	# 计算窗口起始：让 current 出现在第 LEVEL_TRACK_CURRENT 位，但尾部不足时右移
	var total := _level_ids.size()
	var win_start := current_idx - LEVEL_TRACK_CURRENT
	var win_end   := win_start + LEVEL_TRACK_SHOW
	if win_end > total:
		win_end   = total
		win_start = win_end - LEVEL_TRACK_SHOW
	win_start = maxi(win_start, 0)

	var icon_h := 90.0
	var name_h := 24.0
	var node_scale := icon_h / 528.0  # 原图高度 528
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var level_names := _load_level_names()

	for i in range(win_start, mini(win_start + LEVEL_TRACK_SHOW, total)):
		var lid_int := int(_level_ids[i])
		var lid_str: String = String(_level_ids[i])
		var img_key: String
		if lid_int <= _cleared_level:
			img_key = "finished"
		elif i == current_idx:
			img_key = "current"
		else:
			img_key = "locked"

		var node_tex: Texture2D = load(LEVEL_NODE_IMG[img_key])
		var nw := int(node_tex.get_width() * node_scale)

		var is_current := (i == current_idx)

		# 当前关卡用 Button（透明背景），其余用普通 Control
		var wrapper: Control
		if is_current:
			var btn := Button.new()
			var empty_style := StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("normal",  empty_style)
			btn.add_theme_stylebox_override("hover",   empty_style)
			btn.add_theme_stylebox_override("pressed", empty_style)
			btn.add_theme_stylebox_override("focus",   empty_style)
			btn.pressed.connect(func() -> void:
				btn.pivot_offset = btn.size / 2
				var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(0.82, 0.82), 0.1)
				var tw2 := create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
				tw2.tween_interval(0.1)
				tw2.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5)
				_on_level_btn_pressed(_level_ids[i])
			)
			wrapper = btn
		else:
			wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(nw, LEVEL_TRACK_NODE_H)

		var node_rect := TextureRect.new()
		node_rect.texture = node_tex
		node_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node_rect.position = Vector2.ZERO
		node_rect.size = Vector2(nw, icon_h)
		wrapper.add_child(node_rect)

		var num_lbl := Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.position = Vector2.ZERO
		num_lbl.size = Vector2(nw, icon_h)
		num_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		num_lbl.clip_text = false
		var digit_count := str(i + 1).length()
		var fs := 22 - (digit_count - 1) * 4
		var ls := LabelSettings.new()
		ls.font = font
		ls.font_size = fs
		ls.font_color = Color(1.0, 0.95, 0.75)
		ls.outline_size = 4
		ls.outline_color = Color(0.1, 0.05, 0.0, 1.0)
		num_lbl.label_settings = ls
		wrapper.add_child(num_lbl)

		var name_lbl := Label.new()
		name_lbl.text = level_names.get(lid_str, "")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		name_lbl.position = Vector2(-10, icon_h + 2)
		name_lbl.size = Vector2(nw + 20, name_h)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.clip_text = true
		var name_ls := LabelSettings.new()
		name_ls.font = font
		name_ls.font_size = 12
		name_ls.font_color = Color(0.9, 0.88, 0.75)
		name_ls.outline_size = 2
		name_ls.outline_color = Color(0, 0, 0, 0.9)
		name_lbl.label_settings = name_ls
		wrapper.add_child(name_lbl)

		track.add_child(wrapper)

		# 连接线（最后一个节点后不加线）
		if i < mini(win_start + LEVEL_TRACK_SHOW, total) - 1:
			var line_tex: Texture2D = load(LEVEL_NODE_IMG["line"])
			var line_container := Control.new()
			var lw := int(line_tex.get_width() * node_scale)
			line_container.custom_minimum_size = Vector2(lw, LEVEL_TRACK_NODE_H)
			var line_rect := TextureRect.new()
			line_rect.texture = line_tex
			line_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			line_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			line_rect.size = Vector2(lw, icon_h)
			line_rect.position = Vector2(0, 0)
			line_container.add_child(line_rect)
			track.add_child(line_container)

func _refresh_level_info() -> void:
	if _function_panel_node == null:
		return
	var monster_lbl:     Label         = _function_panel_node.get_node_or_null("InfoRow/MonsterBox/MonsterContent")
	var monster_sprites: HBoxContainer = _function_panel_node.get_node_or_null("InfoRow/MonsterBox/MonsterSprites")
	var story_lbl:       Label         = _function_panel_node.get_node_or_null("InfoRow/RewardBox/RewardContent")
	var lid_str := _next_level_id()
	var level_data := _get_level_data(lid_str)

	# 清空旧精灵
	if monster_sprites:
		for c in monster_sprites.get_children():
			c.queue_free()

	if level_data.is_empty():
		if monster_lbl:    monster_lbl.text = "—"
		if story_lbl:      story_lbl.text   = ""
		return

	if story_lbl:
		story_lbl.text = String(level_data.get("desc", ""))

	var monster_ids: Array = String(level_data.get("monster_ids", "")).split(",")
	var _monster_lv: String = String(level_data.get("monster_level", "1"))

	# 统计怪物（去掉占位0，保留顺序去重用于精灵显示）
	var seen: Dictionary = {}
	var ordered_mids: Array = []
	for mid_str in monster_ids:
		var mid := (mid_str as String).strip_edges()
		if mid == "0" or mid.is_empty():
			continue
		if seen.has(mid):
			seen[mid] += 1
		else:
			seen[mid] = 1
			ordered_mids.append(mid)

	# 填充精灵（每种怪物播放 alert 动画）
	const SPRITE_H := 80.0
	if monster_sprites:
		monster_sprites.add_theme_constant_override("separation", 10)
		var m_font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		for mid in ordered_mids:
			var role_data: Dictionary = _roles.get(mid, {})
			var sheet_path: String = String(role_data.get("alert_sheet", ""))
			if sheet_path.is_empty() or not ResourceLoader.exists(sheet_path):
				continue
			var sheet_tex: Texture2D = load(sheet_path)
			var n_frames: int = int(role_data.get("alert_frames", 1))
			var anim_fps: float = float(role_data.get("alert_anim_fps", 12.0))
			@warning_ignore("integer_division")
			var fw := sheet_tex.get_width() / n_frames
			var fh := sheet_tex.get_height()
			var sprite_scale := SPRITE_H / float(fh)

			var sf := SpriteFrames.new()
			sf.add_animation("alert")
			sf.set_animation_speed("alert", anim_fps)
			sf.set_animation_loop("alert", true)
			for f in n_frames:
				var at := AtlasTexture.new()
				at.atlas = sheet_tex
				at.region = Rect2(f * fw, 0, fw, fh)
				at.filter_clip = true
				sf.add_frame("alert", at)

			var sub_vp := SubViewport.new()
			sub_vp.size = Vector2i(int(fw * sprite_scale), int(SPRITE_H))
			sub_vp.transparent_bg = true
			sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

			var anim_sprite := AnimatedSprite2D.new()
			anim_sprite.sprite_frames = sf
			anim_sprite.scale = Vector2(sprite_scale, sprite_scale)
			anim_sprite.position = Vector2(fw * sprite_scale * 0.5, SPRITE_H * 0.5)
			anim_sprite.play("alert")
			sub_vp.add_child(anim_sprite)

			var vpc := SubViewportContainer.new()
			vpc.stretch = true
			vpc.custom_minimum_size = Vector2(int(fw * sprite_scale), int(SPRITE_H))
			vpc.add_child(sub_vp)

			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 2)
			col.add_child(vpc)

			var m_name: String = String(role_data.get("name", ""))
			if seen[mid] > 1:
				m_name += " ×%d" % seen[mid]
			var name_lbl := Label.new()
			name_lbl.text = m_name
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var mls := LabelSettings.new()
			mls.font = m_font
			mls.font_size = 13
			mls.font_color = Color(0.22, 0.13, 0.06, 1)
			mls.outline_size = 1
			mls.outline_color = Color(1, 0.96, 0.85, 0.5)
			name_lbl.label_settings = mls
			col.add_child(name_lbl)

			monster_sprites.add_child(col)


func _get_level_data(lid_str: String) -> Dictionary:
	var text := _read_table_text(LEVELS_TABLE_PATH)
	if text.is_empty():
		return {}
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return {}
	var headers := (raw[0] as String).strip_edges().split("\t")
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 1:
			continue
		if (parts[0] as String).strip_edges() == lid_str:
			var entry: Dictionary = {}
			for j in mini(headers.size(), parts.size()):
				entry[headers[j]] = parts[j]
			return entry
	return {}

func _on_level_btn_pressed(level_id: String) -> void:
	GlobalConfig.set_runtime("scene_mode", "battle")
	GlobalConfig.set_runtime("formation_id", _formation_id)
	GlobalConfig.set_runtime("level_id", level_id)
	var scene := load(BATTLE_SCENE_PATH) as PackedScene
	SceneTransition.change_to(scene)

func _handle_click(pos: Vector2) -> void:
	# 聊天框区域吞掉点击，避免触发建筑/面板逻辑
	if _chat_toggle_rect.has_point(pos):
		return
	if _chat_expanded and _chat_rect.has_point(pos):
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

	if _ad_panel_layer and is_instance_valid(_ad_panel_layer):
		return

	if _ad_rect.has_point(pos):
		_ad_bg.pivot_offset = _ad_bg.size / 2
		_ad_lbl.pivot_offset = _ad_lbl.size / 2
		var tw2 := create_tween()
		tw2.tween_property(_ad_bg, "scale", Vector2(0.82, 0.82), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(_ad_lbl, "scale", Vector2(0.82, 0.82), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_ad_bg, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(_ad_lbl, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		_show_ad_panel()
		return

	if _gm_rect.has_point(pos):
		_gm_bg.pivot_offset = _gm_bg.size / 2
		_gm_lbl.pivot_offset = _gm_lbl.size / 2
		var tw := create_tween()
		tw.tween_property(_gm_bg,  "scale", Vector2(0.82, 0.82), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_gm_lbl, "scale", Vector2(0.82, 0.82), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_gm_bg,  "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_gm_lbl, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		_set_gm_cmd_visible(not _gm_cmd_visible)
		return

	if _gm_cmd_visible:
		for i in _gm_cmd_rects.size():
			if _gm_cmd_rects[i].has_point(pos):
				var action: String = String(_gm_cmd_btns[i].get("action", ""))
				_set_gm_cmd_visible(false)
				if action == "reset":
					_reset_game()
				elif action == "add_resources":
					_gm_add_resources()
				elif action == "grant_all_roles":
					_gm_grant_all_roles()
				elif action == "learn_skill":
					_gm_learn_next_skill()
				elif action == "add_all_equip":
					_gm_add_all_equip()
				return
		return

	# 检测角色点击
	for i in _team_slots.size():
		var entry = _team_slots[i]
		var slot: Node2D = entry["slot"]
		if pos.distance_to(slot.position) < 60.0:
			var rid: String = String(entry.get("role_id", ""))
			_panel_key = "home"
			_refresh_panel()
			_reposition_panel("home")
			_load_function_panel("home")
			_set_panel_visible(true)
			if not rid.is_empty():
				_show_hero_detail(rid)
			return

	for key in _building_nodes:
		if pos.distance_to(BUILDINGS[key]["pos"]) < 80.0:
			if key == "store":
				_show_equip_bag()
				return
			_panel_key = key
			_refresh_panel()
			_reposition_panel(key)
			_load_function_panel(key)
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

func _reposition_panel(_key: String) -> void:
	_panel_rect   = Rect2(0, 0, 1280, 720)
	_upgrade_rect = Rect2(540, 110, 200, 120)
	_close_rect   = Rect2(1090, 10, 85, 80)

func _get_building_level_data(key: String, lv: int) -> Dictionary:
	var levels: Array = _building_configs.get(key, [])
	for entry in levels:
		if int(entry["level"]) == lv:
			return entry
	return {}

func _refresh_panel() -> void:
	if _panel_key == "":
		return
	var state = _building_nodes[_panel_key]
	var cfg = BUILDINGS[_panel_key]
	var lv: int = state["level"]
	_panel_name_lbl.text = "%s  Lv.%d" % [cfg["display"], lv]
	var _font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	_panel_info_lbl.add_theme_font_override("normal_font", _font)
	_panel_info_lbl.add_theme_font_size_override("normal_font_size", 20)
	_panel_info_lbl.add_theme_color_override("default_color", Color(0.22, 0.13, 0.06, 1))
	if _panel_extra_lbl and is_instance_valid(_panel_extra_lbl):
		_panel_extra_lbl.add_theme_font_override("normal_font", _font)
		_panel_extra_lbl.add_theme_font_size_override("normal_font_size", 20)
		_panel_extra_lbl.add_theme_color_override("default_color", Color(0.22, 0.13, 0.06, 1))
	var lv_data: Dictionary = _get_building_level_data(_panel_key, lv)
	var desc: String = lv_data.get("desc", "")
	if _panel_key == "research":
		var skill_cap: int = int(lv_data.get("skill_max_lv", 5))
		desc += "\n当前技能最大等级：[color=#2ebf40]%d[/color]" % skill_cap
	var produces: String = cfg.get("produces", "")
	if produces != "":
		var res_name := "金币" if produces == "gold" else ("木材" if produces == "wood" else "矿石")
		desc += "\n当前产量：[color=#2ebf40]%d[/color] %s / %d 秒" % [PRODUCE_RATES[lv - 1], res_name, int(PRODUCE_INTERVAL)]
		if lv < 3:
			desc += "\n下一级产量：[color=#2ebf40]%d[/color] %s / %d 秒" % [PRODUCE_RATES[lv], res_name, int(PRODUCE_INTERVAL)]
	if _panel_key == "tower":
		var cleared_count: int = maxi(_cleared_level - FIRST_LEVEL_ID + 1, 0)
		var tower_exp: int = cleared_count * TOWER_EXP_PER_LEVEL
		desc += "\n经验产出：[color=#2ebf40]%d[/color] / %d 秒" % [tower_exp, int(TOWER_EXP_INTERVAL)]
	_panel_info_lbl.text = desc
	var extra_text := ""
	if lv >= 3:
		extra_text = "已达最高等级"
		_upgrade_disabled = true
	else:
		var next_data: Dictionary = _get_building_level_data(_panel_key, lv + 1)
		var wood_cost: int = int(next_data.get("wood_cost", 0))
		var ore_cost: int = int(next_data.get("ore_cost", 0))
		var home_lv: int = _building_nodes["home"]["level"]
		if _panel_key != "home" and lv >= home_lv:
			extra_text = "需先升级主基地至 Lv.%d" % (lv + 1)
			_upgrade_disabled = true
		else:
			var gold_cost: int = int(next_data.get("gold_cost", 0))
			var wood_color: String = "#2ebf40" if _wood >= wood_cost else "#e6331a"
			var ore_color: String = "#2ebf40" if _ore >= ore_cost else "#e6331a"
			var gold_color: String = "#2ebf40" if _gold >= gold_cost else "#e6331a"
			var pad := "[color=#00000000]升级消耗：[/color]"
			extra_text = "升级消耗：木材 [color=%s]%d[/color]\n%s矿石 [color=%s]%d[/color]\n%s金币 [color=%s]%d[/color]" % [wood_color, wood_cost, pad, ore_color, ore_cost, pad, gold_color, gold_cost]
			_upgrade_disabled = not (_wood >= wood_cost and _ore >= ore_cost and _gold >= gold_cost)
	if _panel_extra_lbl and is_instance_valid(_panel_extra_lbl):
		_panel_extra_lbl.text = extra_text
		var line_count: int = extra_text.count("\n") + 1
		var area_h := 90.0
		var text_h: float = line_count * 24.0
		_panel_extra_lbl.offset_top = 120.0 + (area_h - text_h) * 0.5
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
	var next_data: Dictionary = _get_building_level_data(_panel_key, lv + 1)
	var wood_cost: int = int(next_data.get("wood_cost", 0))
	var ore_cost: int = int(next_data.get("ore_cost", 0))
	var gold_cost: int = int(next_data.get("gold_cost", 0))
	if _wood < wood_cost or _ore < ore_cost or _gold < gold_cost:
		return
	_wood -= wood_cost
	_ore -= ore_cost
	_gold -= gold_cost
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
	_apply_anim_sheet(key, lv)
	_refresh_label(key)
	# 主基地升级后，刷新其他建筑的灰度状态
	if key == "home":
		for k in _building_nodes:
			if k != "home":
				_refresh_label(k)
	_play_upgrade_fx(BUILDINGS[key]["pos"])
	_play_level_up_sfx()
	if key == "tavern" and _panel_key == "tavern" and _panel_visible:
		_tavern_roll_pool()
		_tavern_reload_panel()

func _apply_anim_sheet(key: String, lv: int) -> void:
	var cfg = BUILDINGS[key]
	var sheet_tex: Texture2D = load(cfg["anim_sheets"][lv - 1])
	var n_frames: int = cfg["n_frames"]
	@warning_ignore("integer_division")
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
	var ref_size: Vector2 = cfg["ref_size"]
	var scale_by_w := (ref_size.x * BUILDING_SCALE) / float(frame_w)
	var scale_by_h := (ref_size.y * BUILDING_SCALE) / float(frame_h)
	anim_sprite.sprite_frames = sf
	anim_sprite.scale = Vector2(minf(scale_by_w, scale_by_h), minf(scale_by_w, scale_by_h))
	anim_sprite.play("idle")

func _tick_production() -> void:
	for key in ["lumberyard", "mine", "home"]:
		if not _building_nodes.has(key):
			continue
		var produces: String = BUILDINGS[key]["produces"]
		if produces.is_empty():
			continue
		var lv: int = _building_nodes[key]["level"]
		var amount: int = PRODUCE_RATES[lv - 1]
		if produces == "wood":
			_wood += amount
			_spawn_float_text(key, amount, "wood")
		elif produces == "ore":
			_ore += amount
			_spawn_float_text(key, amount, "ore")
		elif produces == "gold":
			_gold += amount
			_spawn_float_text(key, amount, "gold")
	_refresh_hud()
	_save_game()

func _tick_tower_exp() -> void:
	if _cleared_level <= 0:
		return
	var cleared_count: int = _cleared_level - FIRST_LEVEL_ID + 1
	var exp_gain: int = cleared_count * TOWER_EXP_PER_LEVEL
	if exp_gain <= 0:
		return
	var any_leveled_up := false
	for rid in _expedition_team_ids:
		if rid.is_empty():
			continue
		var lv: int = int(_role_levels.get(rid, 1))
		var cur_exp: int = int(_role_exps.get(rid, 0)) + exp_gain
		var leveled_up := false
		while true:
			var max_exp: int = int(_level_up_table.get(lv, 0))
			if max_exp <= 0:
				cur_exp = 0
				break
			if cur_exp < max_exp:
				break
			cur_exp -= max_exp
			lv += 1
			leveled_up = true
		_role_levels[rid] = lv
		_role_exps[rid] = cur_exp
		if leveled_up:
			any_leveled_up = true
			_refresh_role_label_for(rid)
	if any_leveled_up:
		_play_level_up_sfx()
	_spawn_float_text("tower", exp_gain, "exp")
	_try_tower_drop()
	_save_game()

func _try_tower_drop() -> void:
	if _equipment_table.is_empty():
		return
	if randf() > TOWER_DROP_CHANCE:
		return
	var tower_lv: int = _building_nodes["tower"]["level"] if _building_nodes.has("tower") else 1
	var equip_level: int = tower_lv * 10
	var ids := _equipment_table.keys()
	# 过滤掉已满上限的类型
	var slot_counts: Dictionary = {}
	for inv_item in _inventory:
		var s: String = String(inv_item.get("slot", ""))
		slot_counts[s] = int(slot_counts.get(s, 0)) + 1
	var valid_ids: Array = []
	for eid_check in ids:
		var tpl_check: Dictionary = _equipment_table[eid_check]
		if int(slot_counts.get(tpl_check["slot"], 0)) < 32:
			valid_ids.append(eid_check)
	if valid_ids.is_empty():
		return
	var eid: int = valid_ids[randi() % valid_ids.size()]
	var tpl: Dictionary = _equipment_table[eid]
	var scale: float = 1.0 + (equip_level - 10) * 0.10
	var item := {
		"id": eid,
		"level": equip_level,
		"name": tpl["name"],
		"slot": tpl["slot"],
		"icon": tpl["icon"],
		"atk": int(randi_range(tpl["atk_min"], tpl["atk_max"]) * scale),
		"def": int(randi_range(tpl["def_min"], tpl["def_max"]) * scale),
		"hp": int(randi_range(tpl["hp_min"], tpl["hp_max"]) * scale),
		"speed": int(randi_range(tpl["speed_min"], tpl["speed_max"]) * scale),
		"crit": int(randi_range(tpl["crit_min"], tpl["crit_max"]) * scale),
		"dodge": int(randi_range(tpl["dodge_min"], tpl["dodge_max"]) * scale),
		"is_new": true,
	}
	_inventory.append(item)
	_refresh_store_new_badge()
	_spawn_equip_float(tpl["name"])

func _spawn_equip_float(equip_name: String) -> void:
	var pos: Vector2 = BUILDINGS["tower"]["pos"]
	var container := Node2D.new()
	container.position = pos + Vector2(0, -30)
	container.z_index = 900
	add_child(container)
	var lbl := Label.new()
	lbl.text = equip_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(160, 30)
	lbl.position = Vector2(-80.0, -15.0)
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size = 20
	ls.font_color = Color(1.0, 0.65, 0.0)
	ls.outline_size = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	lbl.label_settings = ls
	container.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(container, "position:y", pos.y - 65.0, 1.2)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.4).set_delay(0.8)
	tween.tween_callback(container.queue_free)

func _spawn_float_text(key: String, amount: int, resource_type: String) -> void:
	var pos: Vector2 = BUILDINGS[key]["pos"]
	var container := Node2D.new()
	container.position = pos
	container.z_index = 900
	add_child(container)
	var lbl := Label.new()
	if resource_type == "exp":
		lbl.text = "+%d EXP" % amount
	else:
		lbl.text = "+%d" % amount
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(120, 30)
	lbl.position = Vector2(-60.0, -15.0)
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size = 24
	if resource_type == "wood":
		ls.font_color = Color(0.18, 0.75, 0.25)
	elif resource_type == "ore":
		ls.font_color = Color(0.1, 0.1, 0.1)
	elif resource_type == "exp":
		ls.font_color = Color(0.18, 0.8, 0.3)
	else:
		ls.font_color = Color(1.0, 0.82, 0.2)
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
	if key == "store":
		state["label"].text = BUILDINGS[key]["display"]
	else:
		state["label"].text = "%s  Lv.%d" % [BUILDINGS[key]["display"], state["level"]]

func _refresh_bag_tab_badges(tab_slots_arr: Array, tab_new_lbls_arr: Array) -> void:
	for i in tab_slots_arr.size():
		if i < tab_new_lbls_arr.size():
			(tab_new_lbls_arr[i] as Control).visible = _has_new_items(String(tab_slots_arr[i]))

func _has_new_items(slot_filter: String = "") -> bool:
	for item in _inventory:
		if item.get("is_new", false):
			if slot_filter.is_empty() or String(item.get("slot", "")) == slot_filter:
				return true
	return false

func _refresh_store_new_badge() -> void:
	if _store_new_badge and is_instance_valid(_store_new_badge):
		_store_new_badge.visible = _has_new_items()

func _default_skills_copy() -> Array:
	var out: Array = []
	for s in DEFAULT_SKILLS:
		out.append({"id": int(s.get("id", 0)), "level": int(s.get("level", 1))})
	return out

func _serialize_skills(rid: String) -> Array:
	if rid.is_empty():
		return _default_skills_copy()
	var src = _role_skills.get(rid, null)
	if not (src is Array):
		return _default_skills_copy()
	var out: Array = []
	for s in src:
		if s is Dictionary:
			out.append({"id": int(s.get("id", 0)), "level": int(s.get("level", 1))})
	return out

func _parse_skills_array(raw) -> Array:
	if not (raw is Array):
		return _default_skills_copy()
	var out: Array = []
	for s in raw:
		if s is Dictionary and int(s.get("id", 0)) > 0:
			out.append({"id": int(s.get("id", 0)), "level": int(s.get("level", 1))})
		else:
			out.append(null)
	# 去掉末尾连续的 null
	while out.size() > 0 and out.back() == null:
		out.pop_back()
	if out.is_empty():
		return _default_skills_copy()
	return out
func _save_game() -> void:
	var data := {"wood": _wood, "ore": _ore, "gold": _gold, "formation_id": _formation_id, "cleared_level": _cleared_level, "chat_index": _chat_index, "levels": {}, "roles": {}, "owned_roles": _owned_role_ids.duplicate(), "team_ids": _expedition_team_ids.duplicate()}
	# 保留 BattleScene 写入的 battle_speed
	if FileAccess.file_exists(SAVE_PATH):
		var rf := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary and parsed.has("battle_speed"):
				data["battle_speed"] = int(parsed["battle_speed"])
	for key in _building_nodes:
		data["levels"][key] = _building_nodes[key]["level"]
	for rid in _owned_role_ids:
		if rid.is_empty():
			continue
		var role_data: Dictionary = _roles.get(rid, {})
		data["roles"][rid] = {
			"level": int(_role_levels.get(rid, role_data.get("init_level", 1))),
			"star": int(_role_stars.get(rid, role_data.get("init_star", 1))),
			"exp": int(_role_exps.get(rid, 0)),
			"skills": _serialize_skills(rid),
		}
	if not _research_levels.is_empty():
		data["research_levels"] = _research_levels.duplicate()
	data["tavern_pool"] = _tavern_pool.duplicate()
	data["tavern_auto_timer"] = _tavern_auto_timer
	data["tavern_free_refreshes"] = _tavern_free_refreshes
	data["inventory"] = _inventory.duplicate(true)
	data["role_equips"] = _role_equips.duplicate(true)
	data["ad_boost_charges"] = _ad_boost_charges
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
	if data.has("chat_index"):
		_chat_index = int(data["chat_index"])
	if data.has("levels") and data["levels"] is Dictionary:
		var levels: Dictionary = data["levels"]
		for key in levels:
			if not _building_nodes.has(key):
				continue
			var lv: int = clampi(int(levels[key]), 1, 3)
			_building_nodes[key]["level"] = lv
			_apply_anim_sheet(key, lv)
			_refresh_label(key)
	if data.has("roles") and data["roles"] is Dictionary:
		var roles_state: Dictionary = data["roles"]
		for rid in roles_state.keys():
			var s = roles_state[rid]
			if not (s is Dictionary):
				continue
			if s.has("level"):
				_role_levels[rid] = int(s.get("level", 1))
			if s.has("star"):
				_role_stars[rid] = int(s.get("star", 1))
			if s.has("exp"):
				_role_exps[rid] = int(s.get("exp", 0))
			if s.has("skills"):
				_role_skills[rid] = _parse_skills_array(s["skills"])
			_ensure_default_skill(rid)
		# 兜底：所有 owned 角色都补齐属性（防止存档缺字段）
		for rid in _owned_role_ids:
			_ensure_role_data(rid)
		# 刷新所有 team slot 的 UI
		for i in _team_slots.size():
			_refresh_role_label(i)
	if data.has("research_levels") and data["research_levels"] is Dictionary:
		for k in (data["research_levels"] as Dictionary).keys():
			_research_levels[int(k)] = int(data["research_levels"][k])
	if data.has("tavern_pool") and data["tavern_pool"] is Array:
		_tavern_pool = []
		for v in (data["tavern_pool"] as Array):
			_tavern_pool.append(String(v))
	if data.has("tavern_auto_timer"):
		_tavern_auto_timer = float(data["tavern_auto_timer"])
	if data.has("tavern_free_refreshes"):
		_tavern_free_refreshes = int(data["tavern_free_refreshes"])
	if data.has("ad_boost_charges"):
		_ad_boost_charges = int(data["ad_boost_charges"])
	if data.has("inventory") and data["inventory"] is Array:
		_inventory = []
		for item in (data["inventory"] as Array):
			if item is Dictionary:
				_inventory.append(item)
	if data.has("role_equips") and data["role_equips"] is Dictionary:
		_role_equips = {}
		for rid in (data["role_equips"] as Dictionary).keys():
			_role_equips[rid] = data["role_equips"][rid]
	_refresh_store_new_badge()
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
	@warning_ignore("integer_division")
	var fw := tex.get_width() / cols
	@warning_ignore("integer_division")
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

func _get_suit_active_stages(rid: String) -> int:
	var equips: Dictionary = _role_equips.get(rid, {}) if _role_equips.get(rid, null) is Dictionary else {}
	var suit_counts: Dictionary = {}
	for sk in equips.keys():
		var inv_idx: int = int(equips[sk])
		if inv_idx >= 0 and inv_idx < _inventory.size():
			var eid: int = int(_inventory[inv_idx].get("id", 0))
			if _suit_members.has(eid):
				var sn: String = _suit_members[eid]
				suit_counts[sn] = int(suit_counts.get(sn, 0)) + 1
	var stages: int = 0
	for sn in suit_counts.keys():
		var count: int = int(suit_counts[sn])
		for entry in _suit_table:
			if String(entry["name"]) == sn:
				var sid: String = String(entry["suit_id"])
				if _suit_details.has(sid):
					for bonus in _suit_details[sid]:
						if int(bonus["require_count"]) <= count:
							stages += 1
				break
	return stages

func _play_sell_sfx() -> void:
	var stream := load("res://asserts/audio/sell.ogg") as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -3.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_skill_up_sfx() -> void:
	var stream := load("res://asserts/audio/skill_up.ogg") as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -3.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_equip_sfx() -> void:
	var stream := load("res://asserts/audio/equip.ogg") as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -3.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_level_up_sfx() -> void:
	var stream := load("res://asserts/audio/level_up.ogg") as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -3.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_ui_open_sfx() -> void:
	var stream := load("res://asserts/audio/ui_open.ogg") as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -5.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(_play_button_click_sfx)

func _play_button_click_sfx() -> void:
	var stream := load("res://asserts/audio/button_click.ogg") as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -5.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _build_animal_frames() -> void:
	_bird_frames = SpriteFrames.new()
	_bird_frames.add_animation("fly")
	_bird_frames.set_animation_speed("fly", 10.0)
	_bird_frames.set_animation_loop("fly", true)
	var bird_tex: Texture2D = load("res://asserts/image/animal/bird_sheet.png")
	@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
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
			bird.scale = Vector2(0.135, 0.135)
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
			bird.scale = Vector2(0.135, 0.135)
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
			bird.scale = Vector2(0.135, 0.135)
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
			bird.scale = Vector2(0.1125, 0.1125)
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
			sq.scale = Vector2(0.12, 0.12)
			sq.speed_scale = 1.0
		1:
			sq.scale = Vector2(0.12, 0.12)
			sq.speed_scale = 0.95
		2:
			sq.scale = Vector2(0.1125, 0.1125)
			sq.speed_scale = 0.7
		3:
			sq.scale = Vector2(0.12, 0.12)
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

# ─────────────────────────────────────────────────────────────────────────────
# 聊天框（右下角，可展开/收起）
# ─────────────────────────────────────────────────────────────────────────────

func _spawn_chat_box() -> void:
	var ui := $UI
	var vp := get_viewport_rect().size
	var font := load("res://asserts/fonts/ZCOOLKuaiLe.ttf")

	# 切换按钮（始终可见，位于右下角）
	var toggle_w := 92.0
	var toggle_h := 38.0
	var toggle_x := vp.x - toggle_w - 12.0
	var toggle_y := vp.y - toggle_h - 12.0
	_chat_toggle_rect = Rect2(toggle_x, toggle_y, toggle_w, toggle_h)

	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.18, 0.28, 0.45, 0.92)
	tstyle.set_corner_radius_all(10)
	tstyle.border_width_top    = 2
	tstyle.border_width_right  = 2
	tstyle.border_width_bottom = 3
	tstyle.border_width_left   = 2
	tstyle.border_color = Color(0.35, 0.65, 1.0, 0.95)
	tstyle.shadow_color = Color(0, 0, 0, 0.55)
	tstyle.shadow_size  = 6
	tstyle.shadow_offset = Vector2(1, 3)

	_chat_toggle_panel = Panel.new()
	_chat_toggle_panel.size     = Vector2(toggle_w, toggle_h)
	_chat_toggle_panel.position = Vector2(toggle_x, toggle_y)
	_chat_toggle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_toggle_panel.add_theme_stylebox_override("panel", tstyle)
	ui.add_child(_chat_toggle_panel)

	_chat_toggle_lbl = Label.new()
	_chat_toggle_lbl.text = "^ 聊天"
	_chat_toggle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_toggle_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_chat_toggle_lbl.size = Vector2(toggle_w, toggle_h)
	_chat_toggle_lbl.position = Vector2(toggle_x, toggle_y)
	_chat_toggle_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	var tls := LabelSettings.new()
	tls.font = font
	tls.font_size = 20
	tls.font_color = Color(0.88, 0.96, 1.0)
	tls.outline_size = 2
	tls.outline_color = Color(0, 0, 0, 0.9)
	_chat_toggle_lbl.label_settings = tls
	ui.add_child(_chat_toggle_lbl)
	_chat_toggle_lbl.gui_input.connect(_on_chat_toggle_input)

	# 折叠时的最新消息预览（位于切换按钮左侧，单行）
	var preview_w := 360.0
	var preview_h := toggle_h
	var preview_x := toggle_x - preview_w - 8.0
	var preview_y := toggle_y
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.15, 0.22, 0.38, 0.88)
	pstyle.set_corner_radius_all(8)
	pstyle.border_width_top    = 2
	pstyle.border_width_right  = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left   = 2
	pstyle.border_color = Color(0.30, 0.55, 0.95, 0.7)
	_chat_preview_panel = Panel.new()
	_chat_preview_panel.size = Vector2(preview_w, preview_h)
	_chat_preview_panel.position = Vector2(preview_x, preview_y)
	_chat_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_preview_panel.add_theme_stylebox_override("panel", pstyle)
	ui.add_child(_chat_preview_panel)

	_chat_preview_rtl = RichTextLabel.new()
	_chat_preview_rtl.bbcode_enabled = true
	_chat_preview_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chat_preview_rtl.scroll_active = false
	_chat_preview_rtl.clip_contents = true
	_chat_preview_rtl.position = Vector2(preview_x + 10, preview_y + 6)
	_chat_preview_rtl.size = Vector2(preview_w - 20, preview_h - 8)
	_chat_preview_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_preview_rtl.add_theme_font_override("normal_font", font)
	_chat_preview_rtl.add_theme_font_size_override("normal_font_size", 16)
	_chat_preview_rtl.add_theme_constant_override("outline_size", 2)
	_chat_preview_rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	ui.add_child(_chat_preview_rtl)

	# 展开面板（在切换按钮上方）
	var panel_w := 348.0
	var panel_h := 300.0
	var panel_x := vp.x - panel_w - 12.0
	var panel_y := toggle_y - panel_h - 8.0
	_chat_rect = Rect2(panel_x, panel_y, panel_w, panel_h)

	_chat_root = Control.new()
	_chat_root.size = Vector2(panel_w, panel_h)
	_chat_root.position = Vector2(panel_x, panel_y)
	_chat_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_chat_root.visible = false
	ui.add_child(_chat_root)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.18, 0.32, 0.92)
	bg_style.set_corner_radius_all(12)
	bg_style.border_width_top    = 2
	bg_style.border_width_right  = 2
	bg_style.border_width_bottom = 2
	bg_style.border_width_left   = 2
	bg_style.border_color = Color(0.35, 0.65, 1.0, 0.85)
	bg_style.shadow_color = Color(0, 0, 0, 0.6)
	bg_style.shadow_size = 10

	var bg := Panel.new()
	bg.size = Vector2(panel_w, panel_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", bg_style)
	_chat_root.add_child(bg)

	# 标题
	var hdr := Label.new()
	hdr.text = "聊天"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hdr.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hdr.position = Vector2(14, 8)
	hdr.size = Vector2(panel_w - 28, 28)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hls := LabelSettings.new()
	hls.font = font
	hls.font_size = 22
	hls.font_color = Color(1.0, 0.92, 0.6)
	hls.outline_size = 2
	hls.outline_color = Color(0, 0, 0, 0.85)
	hdr.label_settings = hls
	_chat_root.add_child(hdr)

	# 消息滚动区
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.position = Vector2(12, 42)
	_chat_scroll.size = Vector2(panel_w - 24, panel_h - 96)
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_root.add_child(_chat_scroll)

	_chat_msg_box = VBoxContainer.new()
	_chat_msg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_msg_box.add_theme_constant_override("separation", 6)
	_chat_scroll.add_child(_chat_msg_box)

	# 输入行
	var input_y := panel_h - 44.0
	_chat_input = LineEdit.new()
	_chat_input.position = Vector2(12, input_y)
	_chat_input.size = Vector2(panel_w - 92, 32)
	_chat_input.placeholder_text = "说点什么..."
	_chat_input.add_theme_font_override("font", font)
	_chat_input.add_theme_font_size_override("font_size", 18)
	_chat_input.text_submitted.connect(_on_chat_input_submitted)
	_chat_root.add_child(_chat_input)

	var send_w := 64.0
	var send_x := panel_w - send_w - 12.0
	var send_style := StyleBoxFlat.new()
	send_style.bg_color = Color(0.28, 0.52, 0.90, 0.95)
	send_style.set_corner_radius_all(8)
	send_style.border_width_top    = 2
	send_style.border_width_right  = 2
	send_style.border_width_bottom = 2
	send_style.border_width_left   = 2
	send_style.border_color = Color(0.55, 0.80, 1.0, 1.0)

	var send_panel := Panel.new()
	send_panel.size = Vector2(send_w, 32)
	send_panel.position = Vector2(send_x, input_y)
	send_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	send_panel.add_theme_stylebox_override("panel", send_style)
	_chat_root.add_child(send_panel)

	var send_lbl := Label.new()
	send_lbl.text = "发送"
	send_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	send_lbl.size = Vector2(send_w, 32)
	send_lbl.position = Vector2(send_x, input_y)
	send_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	var sls := LabelSettings.new()
	sls.font = font
	sls.font_size = 18
	sls.font_color = Color(1.0, 1.0, 1.0)
	sls.outline_size = 2
	sls.outline_color = Color(0, 0, 0, 0.85)
	send_lbl.label_settings = sls
	_chat_root.add_child(send_lbl)
	send_lbl.gui_input.connect(_on_chat_send_input)

	# 加载聊天表 + 回放历史（保留索引前 5 条）
	_load_chat_table()
	_load_chat_keywords()
	if _chat_index > 0 and not _chat_messages.is_empty():
		var start_i: int = max(0, _chat_index - 5)
		var end_i: int = min(_chat_index, _chat_messages.size())
		for i in range(start_i, end_i):
			var m: Dictionary = _chat_messages[i]
			_chat_add_message(m["speaker"], m["content"])
	_chat_next_delay = randf_range(0.5, 3.0)

func _on_chat_toggle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_chat_expanded(not _chat_expanded)

func _set_chat_expanded(v: bool) -> void:
	_chat_expanded = v
	if _chat_root:
		_chat_root.visible = v
	if _chat_toggle_lbl:
		_chat_toggle_lbl.text = ("v 聊天" if v else "^ 聊天")
	if _chat_preview_panel:
		_chat_preview_panel.visible = not v
	if _chat_preview_rtl:
		_chat_preview_rtl.visible = not v

func _on_chat_send_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_chat_send_current()

func _on_chat_input_submitted(_text: String) -> void:
	_chat_send_current()

func _chat_send_current() -> void:
	if _chat_input == null:
		return
	var t := _chat_input.text.strip_edges()
	if t.is_empty():
		return
	_chat_input.text = ""
	_chat_add_message("玩家", t)
	_check_chat_keyword(t)

func _chat_add_message(speaker: String, content: String) -> void:
	if _chat_msg_box == null:
		return
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_override("normal_font", load("res://asserts/fonts/ZCOOLKuaiLe.ttf"))
	rtl.add_theme_font_size_override("normal_font_size", 17)
	rtl.add_theme_constant_override("outline_size", 2)
	rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var name_color := _chat_name_color(speaker)
	var content_color := _chat_content_color(speaker)
	rtl.text = "[color=%s][%s][/color][color=#cfcfcf]: [/color][color=%s]%s[/color]" % [name_color, speaker, content_color, content]
	_chat_msg_box.add_child(rtl)
	# 同步更新折叠预览（仅显示最新一条）
	if _chat_preview_rtl != null:
		_chat_preview_rtl.text = "[color=%s][%s][/color][color=#cfcfcf]: [/color][color=%s]%s[/color]" % [name_color, speaker, content_color, content]
	# 滚到底部
	await get_tree().process_frame
	if _chat_scroll:
		var v_bar := _chat_scroll.get_v_scroll_bar()
		if v_bar:
			_chat_scroll.scroll_vertical = int(v_bar.max_value)

func _chat_name_color(speaker: String) -> String:
	if speaker == "玩家":
		return "#7CFF7C"
	if speaker == "系统":
		return "#FFC15E"
	var palette := ["#7BC8F6", "#FFB6C1", "#FFD580", "#B0E57C", "#D6A8FF", "#FFE066", "#FF9F80", "#7CC4B6", "#F5A6FF", "#A5D8FF"]
	return palette[abs(speaker.hash()) % palette.size()]

func _chat_content_color(speaker: String) -> String:
	if speaker == "玩家":
		return "#E6FFE6"
	if speaker == "系统":
		return "#FFE6BF"
	return "#EAEAEA"

func _load_chat_table() -> void:
	_chat_messages.clear()
	var f := FileAccess.open(CHAT_TABLE_PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var ln := f.get_line()
		if ln.is_empty():
			continue
		if ln.begins_with("#") or ln.begins_with("id\t"):
			continue
		var parts := ln.split("\t")
		if parts.size() < 3:
			continue
		_chat_messages.append({"speaker": parts[1], "content": parts[2]})
	f.close()

func _load_chat_keywords() -> void:
	_chat_keywords.clear()
	var f := FileAccess.open(CHAT_KEYWORDS_PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var ln := f.get_line()
		if ln.is_empty():
			continue
		if ln.begins_with("#") or ln.begins_with("keyword\t"):
			continue
		var parts := ln.split("\t")
		if parts.size() < 3:
			continue
		var kw: String = parts[0]
		if not _chat_keywords.has(kw):
			_chat_keywords[kw] = []
		_chat_keywords[kw].append({"speaker": parts[1], "content": parts[2]})
	f.close()

func _check_chat_keyword(text: String) -> void:
	for kw in _chat_keywords.keys():
		if text.contains(kw):
			_chat_keyword_queue = _chat_keywords[kw].duplicate()
			_chat_keyword_index = 0
			_chat_keyword_playing = true
			_chat_play_timer = 0.0
			_chat_next_delay = randf_range(0.5, 2.0)
			break

func _tick_chat(delta: float) -> void:
	if _chat_messages.is_empty():
		return
	if _chat_index < 0 or _chat_index >= _chat_messages.size():
		_chat_index = 0
	_chat_play_timer += delta
	if _chat_play_timer < _chat_next_delay:
		return
	_chat_play_timer = 0.0
	_chat_next_delay = randf_range(0.5, 3.0)
	if _chat_keyword_playing:
		if _chat_keyword_index < _chat_keyword_queue.size():
			var m: Dictionary = _chat_keyword_queue[_chat_keyword_index]
			_chat_add_message(m["speaker"], m["content"])
			_chat_keyword_index += 1
		else:
			_chat_keyword_playing = false
			_chat_keyword_queue.clear()
			_chat_keyword_index = 0
		return
	var m: Dictionary = _chat_messages[_chat_index]
	_chat_add_message(m["speaker"], m["content"])
	_chat_index = (_chat_index + 1) % _chat_messages.size()
	_save_game()

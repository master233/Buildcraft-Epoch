extends Node2D
# 简约风：复用主背景 + 暗化遮罩 + 顶部 tip 文字 + 底部胶囊进度条 + 百分比。
# 真实异步预加载，最小显示 1.5s，预加载完成后切到 Main。

const MAIN_SCENE := "res://scenes/Main.tscn"
const MIN_DISPLAY_FALLBACK := 2.0
const TIP_FALLBACK := "感谢老板举办的活动 我们会好好利用这5W的奖金的 ~_~"

# 与建筑等级无关的固定资源
const BASE_PRELOAD: Array[String] = [
	"res://asserts/fonts/ZCOOLKuaiLe.ttf",
	"res://asserts/audio/bg1.wav",
	"res://asserts/image/backgroud/bg_test_1.jpg",
	"res://asserts/image/animal/bird_sheet.png",
	"res://asserts/image/animal/squirrel_sheet.png",
	"res://asserts/image/role/role1_idle_sheet.png",
	"res://asserts/image/ui/star.png",

	# 建筑参考贴图（lv1，用于 _place_buildings 计算缩放，不随等级变）
	"res://asserts/image/building/building_template/home1.png",
	"res://asserts/image/building/building_template/tower1.png",
	"res://asserts/image/building/building_template/lumberyard1.png",
	"res://asserts/image/building/building_template/Mine1.png",
	"res://asserts/image/building/building_template/Tavern1.png",
	"res://asserts/image/building/building_template/research1.png",
]

# 建筑 key → anim_sheet 文件名前缀（与 Main.gd 的 BUILDINGS 路径保持一致）
const BUILDING_SHEET_PREFIX := "res://asserts/image/building/building_anim_sheet/"
const BUILDING_KEYS: Array[String] = [
	"home", "tower", "lumberyard", "mine", "tavern", "research",
]

const BAR_WIDTH := 600.0
const BAR_HEIGHT := 24.0

var _bar: ProgressBar = null
var _ui_layer: CanvasLayer = null
var _start_msec: int = 0
var _smooth_progress: float = 0.0
var _pending: Array[String] = []
var _total_paths: int = 0
var _switched: bool = false
var _armed: bool = false  # 玩家点开始游戏前为 false：可以预加载，但不切到 Main 也不计最短显示时间
var _min_display_sec: float = MIN_DISPLAY_FALLBACK


func _ready() -> void:
	# 同步建 UI，让 LoadingScreen 第一帧就能完整渲染
	_setup()
	# 把资源预加载推迟到下一帧启动，否则 Web 单线程下这一批 load_threaded_request
	# 会卡住 _ready 导致 LoadingScreen 延迟出现
	call_deferred("_kickoff_preload")


func arm() -> void:
	# TitleScreen 点开始游戏后调用：显示 UI、开始计最短显示时间、允许切到 Main
	_armed = true
	_min_display_sec = GlobalConfig.get_float("loading_time", MIN_DISPLAY_FALLBACK)
	_start_msec = Time.get_ticks_msec()
	# 重置视觉进度，让进度条从 0 开始爬升 —— TitleScreen 期间静默预加载可能已让 _smooth_progress 接近 1.0
	_smooth_progress = 0.0
	if _ui_layer:
		_ui_layer.visible = true


func _setup() -> void:
	var vp := get_viewport_rect().size
	var ui := CanvasLayer.new()
	ui.visible = false  # 实例化后默认隐藏，等 arm() 时再显示（被预加载在 TitleScreen 期间静默运行）
	_ui_layer = ui
	add_child(ui)

	var bg := TextureRect.new()
	bg.texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)

	var tip := RichTextLabel.new()
	tip.bbcode_enabled = true
	tip.scroll_active = false
	tip.fit_content = true
	var tip_font := load("res://asserts/fonts/ZCOOLKuaiLe.ttf") as Font
	tip.add_theme_font_override("normal_font", tip_font)
	tip.add_theme_font_size_override("normal_font_size", 32)
	tip.add_theme_color_override("default_color", Color(1.0, 0.94, 0.65))
	tip.add_theme_constant_override("outline_size", 6)
	tip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	tip.add_theme_constant_override("shadow_offset_x", 2)
	tip.add_theme_constant_override("shadow_offset_y", 3)
	tip.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	tip.size = Vector2(vp.x - 80.0, 140.0)
	tip.position = Vector2(40.0, vp.y * 0.62 - 70.0)
	tip.text = "[center]" + GlobalConfig.get_str("loading_tip", TIP_FALLBACK) + "[/center]"
	ui.add_child(tip)

	_bar = ProgressBar.new()
	_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.position = Vector2((vp.x - BAR_WIDTH) * 0.5, vp.y - 70.0)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.value = 0.0
	_bar.show_percentage = true

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.04, 0.02, 0.75)
	bg_style.set_corner_radius_all(12)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.6, 0.45, 0.2, 0.85)
	_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.85, 0.45)
	fill_style.set_corner_radius_all(10)
	_bar.add_theme_stylebox_override("fill", fill_style)

	_bar.add_theme_font_override("font", load("res://asserts/fonts/ZCOOLKuaiLe.ttf"))
	_bar.add_theme_font_size_override("font_size", 14)
	_bar.add_theme_color_override("font_color", Color.WHITE)
	_bar.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_bar.add_theme_constant_override("outline_size", 3)
	ui.add_child(_bar)


func _kickoff_preload() -> void:
	var paths := _build_preload_paths()
	_total_paths = paths.size()
	for p in paths:
		var err := ResourceLoader.load_threaded_request(p)
		if err == OK:
			_pending.append(p)


func _build_preload_paths() -> Array[String]:
	var paths: Array[String] = BASE_PRELOAD.duplicate()
	# 18 张建筑 anim_sheet（6 建筑 × 3 等级）一次性全部预加载，
	# 之后玩家升级建筑时 _apply_anim_sheet 里的 load() 全是缓存命中，无卡顿
	for key in BUILDING_KEYS:
		for lv in range(1, 4):
			paths.append("%s%s%d_anim_sheet.png" % [BUILDING_SHEET_PREFIX, key, lv])
	return paths


func _process(delta: float) -> void:
	if _switched:
		return

	var done_paths: Array[String] = []
	for p in _pending:
		var status := ResourceLoader.load_threaded_get_status(p)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(p)
			ResourceCache.add(res)
			done_paths.append(p)
		elif status == ResourceLoader.THREAD_LOAD_FAILED \
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("LoadingScreen: failed to load " + p)
			done_paths.append(p)
	for p in done_paths:
		_pending.erase(p)

	var done: int = _total_paths - _pending.size()
	var target: float = 0.0 if _total_paths <= 0 else float(done) / float(_total_paths)
	# arm 之前不推进视觉进度（让条停在 0），arm 之后让条均匀爬升占据 _min_display_sec 时段。
	# 速率 = 1 / loading_time，确保进度条 0→1 大约用 loading_time 秒。
	if _armed:
		var rate: float = 1.0 / max(_min_display_sec, 0.1)
		_smooth_progress = move_toward(_smooth_progress, target, delta * rate)
	if _bar:
		_bar.value = _smooth_progress

	if not _armed:
		return
	var elapsed: float = (Time.get_ticks_msec() - _start_msec) / 1000.0
	if _pending.is_empty() and _smooth_progress >= 0.999 and elapsed >= _min_display_sec:
		_switched = true
		get_tree().change_scene_to_file(MAIN_SCENE)

extends Node2D
# 简约风：复用主背景 + 暗化遮罩 + 顶部 tip 文字 + 底部胶囊进度条 + 百分比。
# 真实异步预加载，最小显示 1.5s，预加载完成后切到 Main。

const MAIN_SCENE := "res://scenes/Main.tscn"
const MIN_DISPLAY_SEC := 1.5
const TIP_TEXT := "感谢老板举办的活动 我们会好好利用这5W的奖金的 ~_~"

const PRELOAD_PATHS: Array[String] = [
	"res://asserts/fonts/ZCOOLKuaiLe.ttf",
	"res://asserts/audio/bg1.wav",
	"res://asserts/image/backgroud/bg_test_1.jpg",
	"res://asserts/image/animal/bird_sheet.png",
	"res://asserts/image/animal/squirrel_sheet.png",
	"res://asserts/image/role/role1_idle_sheet.png",

	# 建筑参考贴图（lv1，用于尺寸基准）
	"res://asserts/image/building/building_template/home1.png",
	"res://asserts/image/building/building_template/tower1.png",
	"res://asserts/image/building/building_template/lumberyard1.png",
	"res://asserts/image/building/building_template/Mine1.png",
	"res://asserts/image/building/building_template/Tavern1.png",
	"res://asserts/image/building/building_template/research1.png",

	# 建筑动画序列图 lv1-lv3
	"res://asserts/image/building/building_anim_sheet/home1_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/home2_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/home3_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/tower1_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/tower2_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/tower3_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/lumberyard1_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/lumberyard2_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/lumberyard3_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/mine1_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/mine2_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/mine3_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/tavern1_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/tavern2_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/tavern3_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/research1_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/research2_anim_sheet.png",
	"res://asserts/image/building/building_anim_sheet/research3_anim_sheet.png",
]

const BAR_WIDTH := 600.0
const BAR_HEIGHT := 24.0

var _bar: ProgressBar = null
var _start_msec: int = 0
var _smooth_progress: float = 0.0
var _pending: Array[String] = []
var _switched: bool = false


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	call_deferred("_setup")


func _setup() -> void:
	var vp := get_viewport_rect().size
	var ui := CanvasLayer.new()
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

	var tip := Label.new()
	tip.text = TIP_TEXT
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.size = Vector2(vp.x - 80.0, 60.0)
	tip.position = Vector2(40.0, vp.y * 0.62 - 30.0)
	var tls := LabelSettings.new()
	tls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	tls.font_size = 32
	tls.font_color = Color(1.0, 0.94, 0.65)
	tls.outline_size = 6
	tls.outline_color = Color(0.0, 0.0, 0.0, 0.95)
	tls.shadow_size = 4
	tls.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	tls.shadow_offset = Vector2(2, 3)
	tip.label_settings = tls
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

	for p in PRELOAD_PATHS:
		var err := ResourceLoader.load_threaded_request(p)
		if err == OK:
			_pending.append(p)


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

	var total: int = PRELOAD_PATHS.size()
	var done: int = total - _pending.size()
	var target: float = float(done) / float(max(total, 1))
	_smooth_progress = move_toward(_smooth_progress, target, delta * 1.5)
	if _bar:
		_bar.value = _smooth_progress

	var elapsed: float = (Time.get_ticks_msec() - _start_msec) / 1000.0
	if _pending.is_empty() and _smooth_progress >= 0.999 and elapsed >= MIN_DISPLAY_SEC:
		_switched = true
		get_tree().change_scene_to_file(MAIN_SCENE)

extends Node2D

const LOADING_SCENE: PackedScene = preload("res://scenes/LoadingScreen.tscn")
const MAIN_SCENE := "res://scenes/Main.tscn"

var _btn_ref: TextureButton = null
var _btn_idle_tween: Tween = null
var _starting: bool = false
var _loading_instance: Node = null
var _main_instance: Node = null
var _main_preinstantiated: bool = false
var _main_preinstantiate_frame: int = 0

func _ready() -> void:
	# Web 平台下，HTML 层完全替代 TitleScreen 的视觉与按钮：
	# 不绘制 logo / 按钮，直接同步预加载 + 预实例化 Main，跳过 LoadingScreen 异步逻辑
	# （Web 单线程下 ResourceLoader.load_threaded_* 可能卡住）。
	if OS.has_feature("web"):
		# 推迟一帧再启动同步预加载，让 _ready 先返回，HTML 进度条能正常显示
		call_deferred("_web_kickoff")
		set_process(true)
		return
	call_deferred("_build_ui")
	get_tree().create_timer(0.1).timeout.connect(_pre_instantiate_loading)


func _web_kickoff() -> void:
	# 同步预加载所有 Main._setup 会用到的资源，让 Main 启动时 load() 全部命中缓存
	_preload_main_resources()
	_pre_instantiate_loading()
	_preinstantiate_main()


func _preload_main_resources() -> void:
	var paths := [
		"res://asserts/fonts/ZCOOLKuaiLe.ttf",
		"res://asserts/audio/bg1.wav",
		"res://asserts/image/backgroud/bg_test_1.jpg",
		"res://asserts/image/animal/bird_sheet.png",
		"res://asserts/image/animal/squirrel_sheet.png",
		"res://asserts/image/role/role1_idle_sheet.png",
		"res://asserts/image/ui/star.png",
	]
	# 18 张建筑 anim_sheet
	var keys := ["home", "tower", "lumberyard", "mine", "tavern", "research"]
	for key in keys:
		for lv in range(1, 4):
			paths.append("res://asserts/image/building/building_anim_sheet/%s%d_anim_sheet.png" % [key, lv])
	for p in paths:
		var res := load(p)
		if res != null:
			ResourceCache.add(res)


func _process(_delta: float) -> void:
	if not OS.has_feature("web") or _starting:
		return
	var v: Variant = JavaScriptBridge.eval("window.__bce_start || 0", true)
	if typeof(v) == TYPE_INT and v == 1 or typeof(v) == TYPE_FLOAT and v >= 1.0:
		_on_start_pressed()


func _preinstantiate_main() -> void:
	if _main_preinstantiated:
		return
	_main_preinstantiated = true
	var packed: PackedScene = load(MAIN_SCENE)
	_main_instance = packed.instantiate()
	# 隐藏，但保持 PROCESS_MODE_INHERIT，让 Main._ready 和 call_deferred("_setup") 正常跑
	_main_instance.visible = false
	get_tree().root.add_child(_main_instance)
	if _main_instance.has_node("BGM"):
		var bgm_node := _main_instance.get_node("BGM") as AudioStreamPlayer
		if bgm_node:
			bgm_node.stop()
	# Main._ready → call_deferred("_setup") → _setup 在下一帧跑（约 0.5~1s 阻塞）。
	# 等 3 帧确保 _setup 完成（包括延迟 0.5s 的 _build_upgrade_fx_frames 之外的部分），
	# 再通知 HTML 显示「开始游戏」按钮，让点击瞬切。
	_wait_main_setup_then_notify()


func _wait_main_setup_then_notify() -> void:
	# 等 3 帧 + tween 0.05s（让 deferred _setup 走完同步部分）
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	JavaScriptBridge.eval("window.__bce_assets_ready = 1;", true)

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	var ui := CanvasLayer.new()
	add_child(ui)

	# 背景与遮罩
	var bg := TextureRect.new()
	bg.texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.15, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

	# Logo：入场从缩小+透明开始
	var logo_px := vp.y * 0.63 * 1.5
	var base_scale := logo_px / 1024.0
	var logo := Sprite2D.new()
	logo.texture = load("res://asserts/image/ui/logo.png")
	logo.scale = Vector2(base_scale * 0.6, base_scale * 0.6)
	logo.modulate.a = 0.0
	ui.add_child(logo)

	var btn_w := 448.0
	var btn_h := 182.0
	var block_h := logo_px + 25.0 + btn_h
	var start_y := (vp.y - block_h) / 2.0
	var logo_base_y := start_y + logo_px * 0.5
	logo.position = Vector2(vp.x * 0.5, logo_base_y)

	# 粒子特效
	var particles := CPUParticles2D.new()
	particles.position = logo.position
	particles.emitting = true
	particles.amount = 45
	particles.lifetime = 2.5
	particles.one_shot = false
	particles.randomness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = logo_px * 0.28
	particles.direction = Vector2(0, -1)
	particles.spread = 75.0
	particles.gravity = Vector2(0, -18)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 38.0
	particles.angular_velocity_min = -120.0
	particles.angular_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.35, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	particles.color_ramp = grad
	ui.add_child(particles)

	# 开始游戏按钮：从透明开始，pivot 设中心方便缩放动画
	var btn := TextureButton.new()
	btn.texture_normal = load("res://asserts/image/ui/btn_start.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
	btn.modulate.a = 0.0
	ui.add_child(btn)
	btn.size = Vector2(btn_w, btn_h)
	btn.position = Vector2((vp.x - btn_w) * 0.5, vp.y - btn_h - 40.0)
	btn.pressed.connect(_on_start_pressed)
	btn.mouse_entered.connect(_on_btn_hover)
	btn.mouse_exited.connect(_on_btn_exit)
	btn.button_down.connect(_on_btn_down)
	btn.button_up.connect(_on_btn_release)
	_btn_ref = btn

	# 入场动画：logo 弹出 + 按钮延迟淡入
	var vec_full := Vector2(base_scale, base_scale)
	var vec_big  := Vector2(base_scale * 1.025, base_scale * 1.025)
	var entrance := create_tween()
	entrance.tween_property(logo, "scale", vec_full, 0.75)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.parallel().tween_property(logo, "modulate:a", 1.0, 0.5)
	entrance.parallel().tween_property(btn, "modulate:a", 1.0, 0.4).set_delay(0.5)
	# 入场结束后启动循环动画
	entrance.tween_callback(func():
		var idle := create_tween()
		idle.set_loops()
		idle.tween_property(logo, "position:y", logo_base_y - 10.0, 1.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.parallel().tween_property(logo, "scale", vec_big, 1.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.tween_property(logo, "position:y", logo_base_y, 1.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.parallel().tween_property(logo, "scale", vec_full, 1.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_start_btn_idle()
	)

func _start_btn_idle() -> void:
	if _btn_ref == null:
		return
	if _btn_idle_tween != null:
		_btn_idle_tween.kill()
	_btn_idle_tween = create_tween()
	_btn_idle_tween.set_loops()
	_btn_idle_tween.tween_property(_btn_ref, "modulate:a", 0.72, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_btn_idle_tween.tween_property(_btn_ref, "modulate:a", 1.0, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_btn_hover() -> void:
	if _btn_idle_tween != null:
		_btn_idle_tween.kill()
		_btn_idle_tween = null
	var t := create_tween()
	t.tween_property(_btn_ref, "scale", Vector2(1.07, 1.07), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_btn_ref, "modulate", Color(1.0, 0.95, 0.68, 1.0), 0.12)

func _on_btn_exit() -> void:
	var t := create_tween()
	t.tween_property(_btn_ref, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_btn_ref, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	t.tween_callback(_start_btn_idle)

func _on_btn_down() -> void:
	if _btn_idle_tween != null:
		_btn_idle_tween.kill()
		_btn_idle_tween = null
	var t := create_tween()
	t.tween_property(_btn_ref, "scale", Vector2(0.92, 0.92), 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_btn_release() -> void:
	var t := create_tween()
	t.tween_property(_btn_ref, "scale", Vector2(1.07, 1.07), 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_btn_ref, "scale", Vector2(1.0, 1.0), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _pre_instantiate_loading() -> void:
	if _loading_instance != null:
		return
	# 把 LoadingScreen 要用的大资源塞进 ResourceCache，让 LoadingScreen 内部 load() 命中缓存
	ResourceCache.add(load("res://asserts/image/backgroud/bg_test_1.jpg"))
	ResourceCache.add(load("res://asserts/fonts/ZCOOLKuaiLe.ttf"))
	_loading_instance = LOADING_SCENE.instantiate()
	# 加为 root 的子节点（不是 current_scene）—— LoadingScreen._ready 会跑、
	# UI 已建好但 _ui_layer.visible=false 隐藏，资源预加载在后台静默进行
	get_tree().root.add_child(_loading_instance)


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	if _btn_idle_tween != null:
		_btn_idle_tween.kill()
		_btn_idle_tween = null

	# Web 平台：HTML 层已经一直在显示，所有资源 + Main 场景都已预实例化。
	# 直接显示 Main、设为 current_scene、释放 TitleScreen 即可，跳过 _setup 1 秒卡顿。
	if OS.has_feature("web"):
		if _loading_instance != null:
			_loading_instance.queue_free()
			_loading_instance = null
		ResourceCache.wait_main_ready_and_notify_html()
		if _main_instance != null:
			_main_instance.visible = true
			# 重新启动 BGM（之前预实例化时 stop 了）
			if _main_instance.has_node("BGM"):
				var bgm_node := _main_instance.get_node("BGM") as AudioStreamPlayer
				if bgm_node and bgm_node.stream != null:
					bgm_node.play()
			get_tree().current_scene = _main_instance
			queue_free()
			return
		# 极少见路径：用户点得太快，预实例化还没跑完，回退 change_scene_to_file
		get_tree().change_scene_to_file(MAIN_SCENE)
		return

	# LoadingScreen 已经预实例化好了：arm() 立即显示并开始计最短显示时间
	if _loading_instance == null:
		# 罕见路径：用户点击得太快，预实例化还没跑。回退到普通切场景
		get_tree().change_scene_to_packed(LOADING_SCENE)
		return
	_loading_instance.arm()
	# 把 LoadingScreen 提升为 current_scene，TitleScreen 释放
	var ls = _loading_instance
	get_tree().current_scene = ls
	queue_free()

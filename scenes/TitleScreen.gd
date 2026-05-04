extends Node2D

var _btn_ref: TextureButton = null
var _btn_idle_tween: Tween = null

func _ready() -> void:
	call_deferred("_build_ui")

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
	var base_scale := logo_px / 4096.0
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

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

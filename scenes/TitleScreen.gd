extends Node2D

func _ready() -> void:
	call_deferred("_build_ui")

func _build_ui() -> void:
	var vp := get_viewport_rect().size  # keep 模式下固定返回 1280×720

	var ui := CanvasLayer.new()
	add_child(ui)

	# 背景与遮罩（PRESET_FULL_RECT 在 CanvasLayer 下稳定有效）
	var bg := TextureRect.new()
	bg.texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.15, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

	# Logo：Sprite2D，显示为视口高度的 63%（约 454px）
	var logo_px := vp.y * 0.63
	var logo := Sprite2D.new()
	logo.texture = load("res://asserts/image/ui/logo.png")
	logo.scale = Vector2(logo_px / 4096.0, logo_px / 4096.0)
	ui.add_child(logo)

	# 按钮尺寸 1.5x
	var btn_w := 448.0
	var btn_h := 182.0

	# 整体垂直居中：logo + 间距25 + 按钮
	var block_h := logo_px + 25.0 + btn_h
	var start_y := (vp.y - block_h) / 2.0
	logo.position = Vector2(vp.x * 0.5, start_y + logo_px * 0.5)

	# 开始游戏按钮
	var btn := TextureButton.new()
	btn.texture_normal = load("res://asserts/image/ui/btn_start.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ui.add_child(btn)
	btn.size = Vector2(btn_w, btn_h)
	btn.position = Vector2((vp.x - btn_w) * 0.5, start_y + logo_px + 25.0)
	btn.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

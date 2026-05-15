extends Node2D

const MAIN_SCENE_PATH       := "res://scenes/Main.tscn"
const ROLES_TABLE_PATH      := "res://asserts/table/roles.txt"
const BATTLE_LAYOUT_PATH    := "res://asserts/table/battle_layout.txt"
const GRID_ROWS             := 7
const GRID_COLS             := 12

func _ready() -> void:
	call_deferred("_build_ui")

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	# 背景
	var bg := Sprite2D.new()
	bg.texture = load("res://asserts/image/backgroud/bg_battle.jpg")
	var tex := bg.texture
	var scale_f := max(vp.x / float(tex.get_width()), vp.y / float(tex.get_height()))
	bg.scale = Vector2(scale_f, scale_f)
	bg.position = vp / 2.0
	bg.z_index = -10
	add_child(bg)

	# 放置角色
	_place_battle_roles(vp)

	# UI 层
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	# 右上角退出按钮
	var exit_btn := _make_button("退出", Vector2(vp.x - 120, 16), Vector2(104, 44))
	ui.add_child(exit_btn.panel)
	ui.add_child(exit_btn.label)
	exit_btn.label.gui_input.connect(_on_exit_input)

# ── 解析配置表 ────────────────────────────────────────────────────────────────

func _load_roles_table() -> Dictionary:
	var result := {}
	var file := FileAccess.open(ROLES_TABLE_PATH, FileAccess.READ)
	if not file:
		return result
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 7 or not parts[0].is_valid_int():
			continue
		var rid := int(parts[0])
		result[rid] = {
			"idle_sheet":       parts[2]  if parts.size() > 2  else "",
			"idle_frames":      int(parts[3])   if parts.size() > 3  else 1,
			"idle_scale":       float(parts[4]) if parts.size() > 4  else 0.27,
			"idle_anim_fps":    float(parts[5]) if parts.size() > 5  else 6.0,
			"alert_sheet":      parts[6]  if parts.size() > 6  else "",
			"alert_frames":     int(parts[7])   if parts.size() > 7  else 1,
			"alert_anim_fps":   float(parts[8]) if parts.size() > 8  else 6.0,
		}
	file.close()
	return result

func _load_battle_layout() -> Array:
	var result := []
	var file := FileAccess.open(BATTLE_LAYOUT_PATH, FileAccess.READ)
	if not file:
		return result
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 3 or not parts[0].is_valid_int():
			continue
		result.append({
			"role_id":    int(parts[0]),
			"battle_row": int(parts[1]),
			"battle_col": int(parts[2]),
		})
	file.close()
	return result

# ── 放置战场角色 ──────────────────────────────────────────────────────────────

func _place_battle_roles(vp: Vector2) -> void:
	var cell_w := vp.x / GRID_COLS
	var cell_h := vp.y / GRID_ROWS

	var roles_data   := _load_roles_table()
	var battle_layout := _load_battle_layout()

	for entry in battle_layout:
		var rid   : int   = entry.role_id
		var row   : int   = entry.battle_row   # 1-indexed
		var col   : int   = entry.battle_col   # 1-indexed
		if not roles_data.has(rid):
			continue

		var rd : Dictionary = roles_data[rid]
		if rd.idle_sheet.is_empty() and rd.alert_sheet.is_empty():
			continue

		var sc : float = rd.idle_scale

		# 优先使用 alert，无则回退 idle
		var use_anim   : String
		var sheet_path2 : String
		var frames2    : int
		var fps2       : float
		if rd.alert_sheet != "":
			use_anim    = "alert"
			sheet_path2 = rd.alert_sheet
			frames2     = rd.alert_frames
			fps2        = rd.alert_anim_fps
		else:
			use_anim    = "idle"
			sheet_path2 = rd.idle_sheet
			frames2     = rd.idle_frames
			fps2        = rd.idle_anim_fps

		var tex2 := load(sheet_path2) as Texture2D
		if not tex2:
			continue

		var sf := SpriteFrames.new()
		sf.add_animation(use_anim)
		sf.set_animation_speed(use_anim, fps2)
		sf.set_animation_loop(use_anim, true)
		var frame_w := tex2.get_width() / frames2
		var frame_h := tex2.get_height()
		for i in range(frames2):
			var at := AtlasTexture.new()
			at.atlas  = tex2
			at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			sf.add_frame(use_anim, at)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sf
		sprite.animation     = use_anim
		sprite.scale         = Vector2(sc, sc)
		sprite.position      = Vector2(
			(col - 1) * cell_w + cell_w * 0.5,
			(row - 1) * cell_h + cell_h * 0.5
		)
		sprite.play(use_anim)
		add_child(sprite)

# ── 工具：生成按钮 ────────────────────────────────────────────────────────────

func _make_button(text: String, pos: Vector2, size: Vector2) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color       = Color(0.10, 0.08, 0.05, 0.88)
	style.set_corner_radius_all(10)
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 3
	style.border_width_left   = 2
	style.border_color  = Color(0.80, 0.65, 0.30, 1.0)
	style.shadow_color  = Color(0, 0, 0, 0.55)
	style.shadow_size   = 6
	style.shadow_offset = Vector2(1, 3)

	var panel := Panel.new()
	panel.size     = size
	panel.position = pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size     = size
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	var ls := LabelSettings.new()
	ls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size  = 22
	ls.font_color = Color(1.0, 0.92, 0.6)
	ls.outline_size  = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 1.0)
	ls.shadow_size   = 2
	ls.shadow_color  = Color(0, 0, 0, 0.45)
	lbl.label_settings = ls

	return {"panel": panel, "label": lbl}

func _on_exit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main := load(MAIN_SCENE_PATH) as PackedScene
		SceneTransition.change_to(main)

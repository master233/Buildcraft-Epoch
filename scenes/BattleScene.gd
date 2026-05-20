extends Node2D

const MAIN_SCENE_PATH    := "res://scenes/Main.tscn"
const ROLES_TABLE_PATH   := "res://asserts/table/roles.txt"
const FORMATIONS_TABLE_PATH := "res://asserts/table/formations.txt"
const GRID_ROWS          := 7
const GRID_COLS          := 12

const ROLE_MAX_HP := 100
const ROLE_MAX_MP := 60

# 血条显示参数（相对角色中心）
const BAR_W      := 86.4
const BAR_H      := 9.0
const HP_OFFSET  := Vector2(-43.2, -68.0)
const MP_OFFSET  := Vector2(-43.2, -57.0)

# 阵型选择模式
var _scene_mode: String = ""
var _formations: Array = []          # [{id, name, positions:[Vector2(row,col)]}]
var _current_formation_idx: int = 0
var _formation_role_nodes: Array = [] # 阵型预览模式下放置的角色根节点
var _formation_name_lbl: Label = null

func _ready() -> void:
	call_deferred("_build_ui")

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	var bg := Sprite2D.new()
	bg.texture = load("res://asserts/image/backgroud/bg_battle.jpg")
	var tex: Texture2D = bg.texture
	var scale_f := max(vp.x / float(tex.get_width()), vp.y / float(tex.get_height()))
	bg.scale = Vector2(scale_f, scale_f)
	bg.position = vp / 2.0
	bg.z_index = -10
	add_child(bg)

	_scene_mode = String(GlobalConfig.get_runtime("scene_mode"))

	if _scene_mode == "formation":
		_build_formation_mode(vp)
	else:
		_place_battle_roles(vp)
		var ui := CanvasLayer.new()
		ui.layer = 10
		add_child(ui)
		var exit_btn := _make_button("退出", Vector2(vp.x - 120, 16), Vector2(104, 44))
		ui.add_child(exit_btn.panel)
		ui.add_child(exit_btn.label)
		exit_btn.label.gui_input.connect(_on_exit_input)

# ── 阵型选择模式 ──────────────────────────────────────────────────────────────

func _build_formation_mode(vp: Vector2) -> void:
	_formations = _load_formations_table()
	var init_id: int = int(GlobalConfig.get_runtime("formation_id"))
	if init_id <= 0:
		init_id = 1
	_current_formation_idx = 0
	for i in _formations.size():
		if int(_formations[i]["id"]) == init_id:
			_current_formation_idx = i
			break

	_place_formation_roles(vp, _current_formation_idx)
	_build_formation_overlay(vp)

func _place_formation_roles(vp: Vector2, fidx: int) -> void:
	for n in _formation_role_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_formation_role_nodes.clear()

	if fidx < 0 or fidx >= _formations.size():
		return

	var formation: Dictionary = _formations[fidx]
	var positions: Array = formation["positions"]
	var cell_w := vp.x / GRID_COLS
	var cell_h := vp.y / GRID_ROWS

	var roles_data := _load_roles_table()
	# 出战队伍 ID 列表（从 runtime 取，没有则读存档）
	var team_ids := _get_team_ids()

	for i in mini(team_ids.size(), positions.size()):
		var rc: Vector2 = positions[i]
		if rc == Vector2.ZERO:
			continue
		var row := int(rc.x)
		var col := int(rc.y)
		var rid: String = team_ids[i]
		if not roles_data.has(rid):
			continue
		var rd: Dictionary = roles_data[rid]
		if rd.idle_sheet.is_empty() and rd.alert_sheet.is_empty():
			continue

		var root := Node2D.new()
		root.position = Vector2(
			(col - 1) * cell_w + cell_w * 0.5,
			(row - 1) * cell_h + cell_h * 0.5
		)
		add_child(root)
		_formation_role_nodes.append(root)

		# 优先用警戒动画，没有则回退 idle
		var use_anim: String
		var sheet_path: String
		var frames: int
		var fps: float
		if not rd.alert_sheet.is_empty():
			use_anim   = "alert"
			sheet_path = rd.alert_sheet
			frames     = rd.alert_frames
			fps        = rd.alert_anim_fps
		else:
			use_anim   = "idle"
			sheet_path = rd.idle_sheet
			frames     = rd.idle_frames
			fps        = rd.idle_anim_fps

		var tex2 := load(sheet_path) as Texture2D
		if not tex2:
			continue
		var sf := SpriteFrames.new()
		sf.add_animation(use_anim)
		sf.set_animation_speed(use_anim, fps)
		sf.set_animation_loop(use_anim, true)
		var fw := tex2.get_width() / frames
		var fh := tex2.get_height()
		for f in frames:
			var at := AtlasTexture.new()
			at.atlas  = tex2
			at.region = Rect2(f * fw, 0, fw, fh)
			sf.add_frame(use_anim, at)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sf
		sprite.animation     = use_anim
		sprite.scale         = Vector2(rd.idle_scale, rd.idle_scale)
		sprite.play(use_anim)
		root.add_child(sprite)

func _build_formation_overlay(vp: Vector2) -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	# 顶部选择条背景
	var bar_w := 500.0
	var bar_h := 58.0
	var bar_x := (vp.x - bar_w) * 0.5
	var bar_y := 16.0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.05, 0.10, 0.22, 0.88)
	bar_style.set_corner_radius_all(14)
	bar_style.border_width_top    = 2
	bar_style.border_width_bottom = 2
	bar_style.border_width_left   = 2
	bar_style.border_width_right  = 2
	bar_style.border_color = Color(0.35, 0.70, 1.0, 0.9)
	bar_style.shadow_color = Color(0, 0, 0, 0.5)
	bar_style.shadow_size  = 8

	var bar_panel := Panel.new()
	bar_panel.size     = Vector2(bar_w, bar_h)
	bar_panel.position = Vector2(bar_x, bar_y)
	bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	ui.add_child(bar_panel)

	# 左箭头按钮
	var prev_btn := _make_arrow_button("<", Vector2(bar_x + 10, bar_y + 5), Vector2(44, 48))
	ui.add_child(prev_btn.panel)
	ui.add_child(prev_btn.label)
	prev_btn.label.gui_input.connect(_on_formation_prev)

	# 阵型名称
	_formation_name_lbl = Label.new()
	_formation_name_lbl.text = _formations[_current_formation_idx]["name"] if _formations.size() > 0 else ""
	_formation_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formation_name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_formation_name_lbl.size     = Vector2(bar_w - 120, bar_h)
	_formation_name_lbl.position = Vector2(bar_x + 60, bar_y)
	var nls := LabelSettings.new()
	nls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	nls.font_size  = 26
	nls.font_color = Color(0.85, 0.96, 1.0)
	nls.outline_size  = 3
	nls.outline_color = Color(0, 0, 0, 1.0)
	_formation_name_lbl.label_settings = nls
	ui.add_child(_formation_name_lbl)

	# 右箭头按钮
	var next_btn := _make_arrow_button(">", Vector2(bar_x + bar_w - 54, bar_y + 5), Vector2(44, 48))
	ui.add_child(next_btn.panel)
	ui.add_child(next_btn.label)
	next_btn.label.gui_input.connect(_on_formation_next)

	# 底部 确认 / 取消 按钮
	var confirm_btn := _make_button("✓ 确认", Vector2(vp.x * 0.5 - 135, vp.y - 74), Vector2(120, 52))
	ui.add_child(confirm_btn.panel)
	ui.add_child(confirm_btn.label)
	confirm_btn.label.gui_input.connect(_on_formation_confirm)

	var cancel_btn := _make_button("✗ 取消", Vector2(vp.x * 0.5 + 15, vp.y - 74), Vector2(120, 52))
	ui.add_child(cancel_btn.panel)
	ui.add_child(cancel_btn.label)
	cancel_btn.label.gui_input.connect(_on_formation_cancel)

func _on_formation_prev(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _formations.is_empty():
			return
		_current_formation_idx = (_current_formation_idx - 1 + _formations.size()) % _formations.size()
		_formation_name_lbl.text = _formations[_current_formation_idx]["name"]
		_place_formation_roles(get_viewport_rect().size, _current_formation_idx)

func _on_formation_next(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _formations.is_empty():
			return
		_current_formation_idx = (_current_formation_idx + 1) % _formations.size()
		_formation_name_lbl.text = _formations[_current_formation_idx]["name"]
		_place_formation_roles(get_viewport_rect().size, _current_formation_idx)

func _on_formation_confirm(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _formations.is_empty():
			_go_back_main()
			return
		var f: Dictionary = _formations[_current_formation_idx]
		GlobalConfig.set_runtime("selected_formation_id",   int(f["id"]))
		GlobalConfig.set_runtime("selected_formation_name", String(f["name"]))
		_go_back_main()

func _on_formation_cancel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_go_back_main()

func _go_back_main() -> void:
	var main := load(MAIN_SCENE_PATH) as PackedScene
	SceneTransition.change_to(main)

# ── 解析 formations.txt ───────────────────────────────────────────────────────

func _load_formations_table() -> Array:
	var result: Array = []
	var file := FileAccess.open(FORMATIONS_TABLE_PATH, FileAccess.READ)
	if not file:
		return result
	var text := file.get_as_text()
	file.close()
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var raw := text.split("\n", false)
	# 第一行是表头: id name pos1 pos2 pos3 pos4 pos5
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 3 or not (parts[0] as String).is_valid_int():
			continue
		var positions: Array = []
		for pi in range(2, parts.size()):
			var pstr: String = (parts[pi] as String).strip_edges()
			if pstr.is_empty():
				continue
			var coords := pstr.split(",")
			if coords.size() >= 2:
				var r := int((coords[0] as String).strip_edges())
				var c := int((coords[1] as String).strip_edges())
				if r == 0 and c == 0:
					continue
				positions.append(Vector2(r, c))
		result.append({
			"id":        int(parts[0]),
			"name":      String(parts[1]),
			"positions": positions,
		})
	return result

# ── 获取出战队伍 ID（阵型预览模式下用） ───────────────────────────────────────

func _get_team_ids() -> Array:
	# 从存档读出战队伍
	var save_path := "user://savegame.json"
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary and parsed.has("team_ids") and parsed["team_ids"] is Array:
				var arr: Array[String] = []
				for rid in (parsed["team_ids"] as Array):
					arr.append(String(rid))
				return arr
	# 回退：读 global_config 默认
	var defaults := GlobalConfig.get_str("default_owned_roles", "")
	var result: Array[String] = []
	for piece in defaults.split(","):
		var s: String = (piece as String).strip_edges()
		if not s.is_empty():
			result.append(s)
	return result

# ── 解析 roles.txt ────────────────────────────────────────────────────────────

func _load_roles_table() -> Dictionary:
	var result := {}
	var file := FileAccess.open(ROLES_TABLE_PATH, FileAccess.READ)
	if not file:
		return result
	var text := file.get_as_text()
	file.close()
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return result
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
		result[rid] = {
			"idle_sheet":    String(entry.get("idle_sheet", "")),
			"idle_frames":   int(entry.get("idle_frames", "1")),
			"idle_scale":    float(entry.get("idle_scale", "0.27")),
			"idle_anim_fps": float(entry.get("idle_anim_fps", "6.0")),
			"alert_sheet":   String(entry.get("alert_sheet", "")),
			"alert_frames":  int(entry.get("alert_frames", "1")),
			"alert_anim_fps":float(entry.get("alert_anim_fps", "6.0")),
		}
	return result

# ── 正常出战：放置战场角色（读阵型配置） ─────────────────────────────────────

func _place_battle_roles(vp: Vector2) -> void:
	var cell_w := vp.x / GRID_COLS
	var cell_h := vp.y / GRID_ROWS

	var roles_data    := _load_roles_table()
	var formation_id  := int(GlobalConfig.get_runtime("formation_id"))
	if formation_id <= 0:
		formation_id = 1

	var formations    := _load_formations_table()
	var formation_positions: Array = []
	for f in formations:
		if int(f["id"]) == formation_id:
			formation_positions = f["positions"]
			break

	var team_ids := _get_team_ids()

	var hp_tex := load("res://asserts/image/ui/hp_bar.png") as Texture2D
	var mp_tex := load("res://asserts/image/ui/mp_bar.png") as Texture2D
	var font   := load("res://asserts/fonts/ZCOOLKuaiLe.ttf") as Font

	for i in mini(team_ids.size(), formation_positions.size()):
		var rc: Vector2 = formation_positions[i]
		if rc == Vector2.ZERO:
			continue
		var row := int(rc.x)
		var col := int(rc.y)
		var rid: String = team_ids[i]
		if not roles_data.has(rid):
			continue

		var rd: Dictionary = roles_data[rid]
		if rd.idle_sheet.is_empty() and rd.alert_sheet.is_empty():
			continue

		var sc: float = rd.idle_scale
		var use_anim:   String
		var sheet_path: String
		var frames2:    int
		var fps2:       float
		if rd.alert_sheet != "":
			use_anim   = "alert"
			sheet_path = rd.alert_sheet
			frames2    = rd.alert_frames
			fps2       = rd.alert_anim_fps
		else:
			use_anim   = "idle"
			sheet_path = rd.idle_sheet
			frames2    = rd.idle_frames
			fps2       = rd.idle_anim_fps

		var tex2 := load(sheet_path) as Texture2D
		if not tex2:
			continue

		var sf := SpriteFrames.new()
		sf.add_animation(use_anim)
		sf.set_animation_speed(use_anim, fps2)
		sf.set_animation_loop(use_anim, true)
		var frame_w := tex2.get_width() / frames2
		var frame_h := tex2.get_height()
		for k in range(frames2):
			var at := AtlasTexture.new()
			at.atlas  = tex2
			at.region = Rect2(k * frame_w, 0, frame_w, frame_h)
			sf.add_frame(use_anim, at)

		var root := Node2D.new()
		root.position = Vector2(
			(col - 1) * cell_w + cell_w * 0.5,
			(row - 1) * cell_h + cell_h * 0.5
		)
		add_child(root)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = sf
		sprite.animation     = use_anim
		sprite.scale         = Vector2(sc, sc)
		sprite.play(use_anim)
		root.add_child(sprite)

		var bar := RoleStatusBar.new(
			ROLE_MAX_HP, ROLE_MAX_MP,
			hp_tex, mp_tex, font,
			BAR_W, BAR_H, HP_OFFSET, MP_OFFSET
		)
		root.add_child(bar)

# ── 镜像工具（怪物右侧时用） ──────────────────────────────────────────────────
static func mirror_col(col: int) -> int:
	return GRID_COLS + 1 - col  # 13 - col

# ── 血条节点类 ────────────────────────────────────────────────────────────────

class RoleStatusBar extends Node2D:
	var cur_hp : int
	var max_hp : int
	var cur_mp : int
	var max_mp : int
	var hp_tex : Texture2D
	var mp_tex : Texture2D
	var font   : Font
	var bar_w  : float
	var bar_h  : float
	var hp_off : Vector2
	var mp_off : Vector2

	func _init(mhp:int, mmp:int, htex:Texture2D, mtex:Texture2D,
			   fnt:Font, bw:float, bh:float, hoff:Vector2, moff:Vector2) -> void:
		cur_hp = mhp; max_hp = mhp
		cur_mp = mmp; max_mp = mmp
		hp_tex = htex; mp_tex = mtex
		font = fnt
		bar_w = bw; bar_h = bh
		hp_off = hoff; mp_off = moff

	func _draw() -> void:
		_draw_bar(hp_off, cur_hp, max_hp, hp_tex)
		_draw_bar(mp_off, cur_mp, max_mp, mp_tex)

	func _draw_bar(off: Vector2, cur: int, mx: int, frame: Texture2D) -> void:
		if frame:
			draw_texture_rect(frame, Rect2(off, Vector2(bar_w, bar_h)), false)
		var txt := "%d/%d" % [cur, mx]
		var font_size := 8
		var txt_size  := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var txt_pos   := off + Vector2((bar_w - txt_size.x) * 0.5, bar_h * 0.5 + txt_size.y * 0.35)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx != 0 or dy != 0:
					draw_string(font, txt_pos + Vector2(dx, dy), txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
		draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 1))

# ── 工具：生成普通按钮 ────────────────────────────────────────────────────────

func _make_button(text: String, pos: Vector2, size: Vector2) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.05, 0.88)
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

# ── 工具：生成箭头按钮（纯文字，蓝色风格） ────────────────────────────────────

func _make_arrow_button(text: String, pos: Vector2, size: Vector2) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.28, 0.58, 0.85)
	style.set_corner_radius_all(8)
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_color = Color(0.35, 0.70, 1.0, 0.9)

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
	ls.font_size  = 28
	ls.font_color = Color(0.85, 0.96, 1.0)
	ls.outline_size  = 3
	ls.outline_color = Color(0, 0, 0, 1.0)
	lbl.label_settings = ls

	return {"panel": panel, "label": lbl}

func _on_exit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main := load(MAIN_SCENE_PATH) as PackedScene
		SceneTransition.change_to(main)

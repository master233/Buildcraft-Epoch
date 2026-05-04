extends Node2D

@onready var bgm: AudioStreamPlayer = $BGM
@onready var _wood_lbl: Label = $UI/WoodLbl
@onready var _ore_lbl: Label = $UI/OreLbl
@onready var _panel_dim: ColorRect = $UI/PanelDim
@onready var _panel_bg: ColorRect = $UI/PanelBg
@onready var _panel_border: ColorRect = $UI/PanelBorder
@onready var _panel_name_lbl: Label = $UI/PanelNameLbl
@onready var _panel_sep: ColorRect = $UI/PanelSep
@onready var _panel_info_lbl: Label = $UI/PanelInfoLbl
@onready var _upgrade_bg: ColorRect = $UI/UpgradeBg
@onready var _upgrade_lbl: Label = $UI/UpgradeLbl
@onready var _close_bg: ColorRect = $UI/CloseBg
@onready var _close_lbl: Label = $UI/CloseLbl

const BUILDING_SCALE := 0.8
const PRODUCE_INTERVAL := 5.0
const PRODUCE_RATES := [3, 6, 12]
const SAVE_PATH := "user://savegame.json"

const PANEL_RECT   := Rect2(470, 250, 340, 220)
const UPGRADE_RECT := Rect2(500, 412, 130, 44)
const CLOSE_RECT   := Rect2(650, 412, 130, 44)

const BUILDINGS := {
	"home": {
		"paths": ["res://asserts/image/building/home1.png", "res://asserts/image/building/home2.png", "res://asserts/image/building/home3.png"],
		"pos": Vector2(640, 375), "display": "主基地", "y_adj": 25,
		"upgrade_cost": [{"wood": 100, "ore": 80}, {"wood": 250, "ore": 200}],
		"produces": ""
	},
	"tower": {
		"paths": ["res://asserts/image/building/tower1.png", "res://asserts/image/building/tower2.png", "res://asserts/image/building/tower3.png"],
		"pos": Vector2(640, 150), "display": "远征塔", "y_adj": 0,
		"upgrade_cost": [{"wood": 80, "ore": 50}, {"wood": 200, "ore": 130}],
		"produces": ""
	},
	"lumberyard": {
		"paths": ["res://asserts/image/building/lumberyard1.png", "res://asserts/image/building/lumberyard2.png", "res://asserts/image/building/lumberyard3.png"],
		"pos": Vector2(210, 275), "display": "伐木场", "y_adj": 25,
		"upgrade_cost": [{"wood": 50, "ore": 20}, {"wood": 120, "ore": 60}],
		"produces": "wood"
	},
	"mine": {
		"paths": ["res://asserts/image/building/Mine1.png", "res://asserts/image/building/Mine2.png", "res://asserts/image/building/Mine3.png"],
		"pos": Vector2(1070, 275), "display": "矿石场", "y_adj": 0,
		"upgrade_cost": [{"wood": 30, "ore": 50}, {"wood": 80, "ore": 130}],
		"produces": "ore"
	},
	"tavern": {
		"paths": ["res://asserts/image/building/Tavern1.png", "res://asserts/image/building/Tavern2.png", "res://asserts/image/building/Tavern3.png"],
		"pos": Vector2(270, 510), "display": "酒馆", "y_adj": 0,
		"upgrade_cost": [{"wood": 60, "ore": 40}, {"wood": 150, "ore": 100}],
		"produces": ""
	},
	"research": {
		"paths": ["res://asserts/image/building/research1.png", "res://asserts/image/building/research2.png", "res://asserts/image/building/research3.png"],
		"pos": Vector2(1010, 510), "display": "研究院", "y_adj": 0,
		"upgrade_cost": [{"wood": 40, "ore": 60}, {"wood": 100, "ore": 150}],
		"produces": ""
	},
}

var _wood: int = 200
var _ore: int = 100
var _building_nodes: Dictionary = {}
var _produce_timer: float = 0.0
var _panel_key: String = ""
var _panel_visible: bool = false
var _panel_nodes: Array = []
var _upgrade_disabled: bool = false
var _bird_frames: SpriteFrames = null
var _squirrel_frames: SpriteFrames = null
var _bird_next_pattern: Array[int] = [0, 1, 2]

func _ready() -> void:
	bgm.stream = load("res://asserts/audio/bg1.wav")
	bgm.volume_db = 0.0
	bgm.play()
	_panel_nodes = [_panel_dim, _panel_bg, _panel_border, _panel_name_lbl,
					_panel_sep, _panel_info_lbl, _upgrade_bg, _upgrade_lbl, _close_bg, _close_lbl]
	call_deferred("_setup")

func _setup() -> void:
	var vp := get_viewport_rect().size
	var half_vp := vp / 2.0

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
	_load_game()
	_refresh_hud()
	_build_animal_frames()
	_spawn_bird(0)
	get_tree().create_timer(6.0).timeout.connect(_spawn_bird.bind(1))
	get_tree().create_timer(13.0).timeout.connect(_spawn_bird.bind(2))
	_spawn_squirrel(0.12, 0.73)
	get_tree().create_timer(8.0).timeout.connect(_spawn_squirrel.bind(0.88, 0.77))

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
		add_child(container)

		var sprite := Sprite2D.new()
		sprite.texture = load(cfg["paths"][0])
		sprite.scale = Vector2(BUILDING_SCALE, BUILDING_SCALE)
		container.add_child(sprite)

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
		label.position = Vector2(-90.0, -(sprite.texture.get_height() * BUILDING_SCALE * 0.35) - 8.0 + cfg["y_adj"])

		_building_nodes[key] = {"level": 1, "sprite": sprite, "label": label}
		_refresh_label(key)

func _set_panel_visible(v: bool) -> void:
	var a := 1.0 if v else 0.0
	for node in _panel_nodes:
		node.modulate.a = a
	_panel_visible = v

func _handle_click(pos: Vector2) -> void:
	if _panel_visible:
		if UPGRADE_RECT.has_point(pos) and not _upgrade_disabled:
			_on_upgrade_pressed()
			return
		if CLOSE_RECT.has_point(pos):
			_set_panel_visible(false)
			_panel_key = ""
			return
		if PANEL_RECT.has_point(pos):
			return
		_set_panel_visible(false)
		_panel_key = ""
		return
	for key in _building_nodes:
		if pos.distance_to(BUILDINGS[key]["pos"]) < 80.0:
			_panel_key = key
			_refresh_panel()
			_set_panel_visible(true)
			return

func _refresh_panel() -> void:
	if _panel_key == "":
		return
	var state = _building_nodes[_panel_key]
	var cfg = BUILDINGS[_panel_key]
	var lv: int = state["level"]
	_panel_name_lbl.text = cfg["display"]
	if lv >= 3:
		_panel_info_lbl.text = "等级：%d / 3\n\n已达最高等级" % lv
		_upgrade_disabled = true
		_upgrade_bg.color = Color(0.3, 0.3, 0.3)
	else:
		var cost = cfg["upgrade_cost"][lv - 1]
		var home_lv: int = _building_nodes["home"]["level"]
		if _panel_key != "home" and lv >= home_lv:
			_panel_info_lbl.text = "等级：%d / 3\n\n需先升级主基地至 Lv.%d" % [lv, lv + 1]
			_upgrade_disabled = true
			_upgrade_bg.color = Color(0.3, 0.3, 0.3)
		else:
			var ok: bool = _wood >= int(cost["wood"]) and _ore >= int(cost["ore"])
			_panel_info_lbl.text = "等级：%d / 3\n\n升级消耗：木材 %d   矿石 %d" % [lv, int(cost["wood"]), int(cost["ore"])]
			_upgrade_disabled = not ok
			_upgrade_bg.color = Color(0.18, 0.48, 0.12) if ok else Color(0.3, 0.3, 0.3)

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
	state["sprite"].texture = load(BUILDINGS[key]["paths"][state["level"] - 1])
	_refresh_label(key)

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
		_wood_lbl.text = "木材  %d" % _wood
	if _ore_lbl:
		_ore_lbl.text = "矿石  %d" % _ore

func _refresh_label(key: String) -> void:
	var state = _building_nodes[key]
	state["label"].text = "%s  Lv.%d" % [BUILDINGS[key]["display"], state["level"]]

func _save_game() -> void:
	var data := {"wood": _wood, "ore": _ore, "levels": {}}
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
	if data.has("levels") and data["levels"] is Dictionary:
		var levels: Dictionary = data["levels"]
		for key in levels:
			if not _building_nodes.has(key):
				continue
			var lv: int = clampi(int(levels[key]), 1, 3)
			_building_nodes[key]["level"] = lv
			_building_nodes[key]["sprite"].texture = load(BUILDINGS[key]["paths"][lv - 1])
			_refresh_label(key)

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

func _spawn_squirrel(start_x_frac: float = 0.12, ground_y_frac: float = 0.75) -> void:
	var vp := get_viewport_rect().size
	var sq := AnimatedSprite2D.new()
	sq.sprite_frames = _squirrel_frames
	sq.z_index = 1

	var gait := randi() % 4
	sq.set_meta("gait", gait)
	match gait:
		0:
			sq.scale = Vector2(0.06, 0.06)
			sq.speed_scale = 1.0
		1:
			sq.scale = Vector2(0.06375, 0.06375)
			sq.speed_scale = 1.4
		2:
			sq.scale = Vector2(0.05625, 0.05625)
			sq.speed_scale = 0.7
		3:
			sq.scale = Vector2(0.06, 0.06)
			sq.speed_scale = 0.9

	var ground_y := vp.y * ground_y_frac
	var left_x   := vp.x * 0.12
	var right_x  := vp.x * 0.88
	sq.position = Vector2(vp.x * start_x_frac, ground_y)
	sq.play("run")
	add_child(sq)
	_squirrel_wander(sq, left_x, right_x, ground_y)

func _squirrel_wander(sq: AnimatedSprite2D, left_x: float, right_x: float, ground_y: float) -> void:
	if not is_instance_valid(sq):
		return

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
			speed = 70.0
			bounce_amp = 10.0
			hop_count = 5
			pause_min = 0.3
			pause_max = 1.2
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

	var target_x: float = randf_range(left_x, right_x)
	var start_x: float = sq.position.x
	var dist: float = abs(target_x - start_x)

	if dist < 30.0:
		target_x = right_x if sq.position.x < (left_x + right_x) * 0.5 else left_x
		dist = abs(target_x - start_x)

	var max_dist: float = speed * 5.0
	if dist > max_dist:
		target_x = start_x + max_dist * sign(target_x - start_x)
		dist = max_dist

	var going_right: bool = target_x > start_x
	sq.flip_h = not going_right
	var duration: float = dist / speed
	sq.play("run")

	var t := create_tween()
	t.tween_method(func(p: float) -> void:
		if not is_instance_valid(sq):
			return
		sq.position.x = lerp(start_x, target_x, p)
		sq.position.y = ground_y - abs(sin(p * PI * hop_count)) * bounce_amp
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		if not is_instance_valid(sq):
			return
		sq.stop()
		var pause := get_tree().create_timer(randf_range(pause_min, pause_max))
		pause.timeout.connect(func() -> void:
			_squirrel_wander(sq, left_x, right_x, ground_y)
		)
	)

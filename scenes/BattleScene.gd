extends Node2D

const MAIN_SCENE_PATH       := "res://scenes/Main.tscn"
const BATTLE_SCENE_PATH     := "res://scenes/BattleScene.tscn"
const ROLES_TABLE_PATH      := "res://asserts/table/roles.txt"
const ROLE_ATTRS_TABLE_PATH := "res://asserts/table/role_attrs.txt"
const FORMATIONS_TABLE_PATH := "res://asserts/table/formations.txt"
const LEVELS_TABLE_PATH     := "res://asserts/table/levels.txt"
const LEVEL_UP_TABLE_PATH   := "res://asserts/table/level_up.txt"
const SKILL_TABLE_PATH      := "res://asserts/table/skill.txt"
const DEFAULT_SKILLS: Array = []
const GRID_ROWS := 7
const GRID_COLS := 12

# 血条显示参数（相对角色中心）
const BAR_W     := 86.4
const BAR_H     := 15.0
const HP_OFFSET := Vector2(-43.2, -68.0)
const MP_OFFSET := Vector2(-43.2, -57.0)

# 战斗参数
const ACTION_INTERVAL := 0.15  # 单位行动之间的间隔（秒）
const MOVE_IN_TIME    := 0.25  # 冲到目标前的耗时
const MOVE_OUT_TIME   := 0.25  # 退回原位的耗时
const APPROACH_OFFSET := 70.0  # 攻击者距目标的横向偏移

# 阵型选择模式
var _scene_mode: String = ""
var _formations: Array = []
var _current_formation_idx: int = 0
var _formation_role_nodes: Array = []
var _formation_name_lbl: Label = null

# 战斗状态
var _battle_units: Array = []   # Array of BattleUnit（玩家+敌方）
var _battle_over: bool = false
var _action_timer: float = 0.0
var _round_queue: Array = []    # 当前回合剩余待行动单位（按 spd 降序）
var _round_number: int = 0
var _round_label: Label = null
var _acting: bool = false       # 正在演出某单位行动序列

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	call_deferred("_build_ui")

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	var bg := Sprite2D.new()
	bg.texture = load("res://asserts/image/backgroud/bg_battle.jpg")
	var tex: Texture2D = bg.texture
	var scale_f: float = max(vp.x / float(tex.get_width()), vp.y / float(tex.get_height()))
	bg.scale    = Vector2(scale_f, scale_f)
	bg.position = vp / 2.0
	bg.z_index  = -10
	add_child(bg)

	_scene_mode = String(GlobalConfig.get_runtime("scene_mode"))

	if _scene_mode == "formation":
		_build_formation_mode(vp)
	else:
		_place_battle_roles(vp)
		_place_enemy_roles(vp)
		var ui := CanvasLayer.new()
		ui.layer = 10
		add_child(ui)
		_build_round_label(ui, vp)
		var exit_btn := _make_button("退出", Vector2(vp.x - 120, 16), Vector2(104, 44))
		ui.add_child(exit_btn.panel)
		ui.add_child(exit_btn.label)
		exit_btn.label.gui_input.connect(_on_exit_input)

func _build_round_label(ui: CanvasLayer, vp: Vector2) -> void:
	var lbl_w := 240.0
	var lbl_h := 50.0
	var lbl := Label.new()
	lbl.text = "第 1 回合"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(lbl_w, lbl_h)
	lbl.position = Vector2((vp.x - lbl_w) * 0.5, 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font          = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size     = 30
	ls.font_color    = Color(1.0, 0.92, 0.6)
	ls.outline_size  = 4
	ls.outline_color = Color(0, 0, 0, 1.0)
	ls.shadow_size   = 3
	ls.shadow_color  = Color(0, 0, 0, 0.6)
	lbl.label_settings = ls
	ui.add_child(lbl)
	_round_label = lbl

# ─────────────────────────────────────────────────────────────────────────────
# 战斗主循环
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _battle_over or _battle_units.is_empty() or _scene_mode == "formation":
		return
	if _acting:
		return

	_action_timer += delta
	if _action_timer < ACTION_INTERVAL:
		return
	_action_timer = 0.0

	# 当前回合行动队列空了，开新回合
	if _round_queue.is_empty():
		_start_new_round()
		if _round_queue.is_empty():
			return

	# 一次 tick 只启动一个单位的行动序列
	while not _round_queue.is_empty():
		var unit: BattleUnit = _round_queue.pop_front()
		if unit.is_dead:
			continue
		# 晕眩：本回合跳过，并消耗晕眩
		if unit.stunned:
			_clear_stun(unit)
			continue
		_perform_action(unit)
		return

func _perform_action(attacker: BattleUnit) -> void:
	_acting = true

	# 找对方阵营存活的随机目标
	var targets: Array = []
	for u in _battle_units:
		var candidate := u as BattleUnit
		if not candidate.is_dead and candidate.is_enemy != attacker.is_enemy:
			targets.append(candidate)
	if targets.is_empty():
		_acting = false
		return
	var target := targets[randi() % targets.size()] as BattleUnit

	var atk_root: Node2D = attacker.root
	if not is_instance_valid(atk_root) or not is_instance_valid(target.root):
		_acting = false
		return

	var origin: Vector2 = atk_root.position
	var origin_z: int = atk_root.z_index
	# 玩家攻击者从左来 → 站到目标左侧；敌人攻击者从右来 → 站到目标右侧
	var off_x: float = -APPROACH_OFFSET if not attacker.is_enemy else APPROACH_OFFSET
	var dest: Vector2 = target.root.position + Vector2(off_x, 0)

	# 攻击期间让攻击者图层置顶，避免被受击者遮挡（飘字 z=100 仍在最上）
	atk_root.z_index = 10

	# 1) 冲到目标前
	var tw_in := create_tween()
	tw_in.tween_property(atk_root, "position", dest, MOVE_IN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	# 2) 播攻击动画 → 0.4s 后扣血 + 飘字 → 等动画播完回 alert
	var sf: SpriteFrames = null
	var has_atk_anim := false
	if is_instance_valid(attacker.sprite):
		sf = attacker.sprite.sprite_frames
		if sf and sf.has_animation("attack"):
			has_atk_anim = true
			attacker.sprite.play("attack")
	await get_tree().create_timer(0.4).timeout
	var ignore_dodge := _try_eagle_eye(attacker)
	var hit := _apply_damage(attacker, target, 1.0, ignore_dodge)
	if has_atk_anim and is_instance_valid(attacker.sprite):
		if attacker.sprite.animation == "attack" and attacker.sprite.is_playing():
			await attacker.sprite.animation_finished
		if is_instance_valid(attacker.sprite):
			var back := "alert" if sf.has_animation("alert") else "idle"
			if sf.has_animation(back):
				attacker.sprite.play(back)

	# 2.5) 连击（30001）：攻击时有 p1% 概率追加一次 p2% 伤害
	await _try_combo_strike(attacker, target, sf, has_atk_anim)

	# 2.55) 攻防一体（40001）：普攻命中后附加 护甲*p1% 物理伤害（miss 不触发）
	if hit:
		await _try_armor_strike(attacker, target)

	# 2.57) 野蛮冲撞（40005）：普攻命中后 p1% 概率晕眩目标一回合
	if hit:
		_try_brutal_stun(attacker, target)

	# 2.6) 反击（30002）：目标对攻击者进行 p1% 概率反击 p2% 伤害
	await _try_counter_strike(attacker, target)

	# 3) 退回原位
	if is_instance_valid(atk_root):
		var tw_out := create_tween()
		tw_out.tween_property(atk_root, "position", origin, MOVE_OUT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_out.finished
		if is_instance_valid(atk_root):
			atk_root.z_index = origin_z

	_check_battle_over()
	_acting = false

func _apply_damage(attacker: BattleUnit, target: BattleUnit, dmg_mult: float = 1.0, ignore_dodge: bool = false) -> bool:
	var is_crit := (randi() % 10000) < attacker.crit
	var dmg_base: int = max(1, attacker.atk - target.def)
	var dmg := int(dmg_base * (1.5 if is_crit else 1.0) * dmg_mult)
	dmg = max(1, dmg)
	var is_miss := false
	if not ignore_dodge and (randi() % 10000) < target.dodge:
		dmg = 0
		is_miss = true
	target.cur_hp = max(0, target.cur_hp - dmg)
	target.status_bar.update_hp(target.cur_hp)
	_spawn_damage_label(target, dmg, is_miss, is_crit)
	if is_miss:
		return false
	if dmg > 0:
		_apply_drain(target, dmg)
	var dying := target.cur_hp <= 0
	if dying:
		target.is_dead = true
	target.play_hurt_then(dying)
	return true

func _find_skill(unit: BattleUnit, skill_id: int) -> Dictionary:
	if unit == null:
		return {}
	for s in unit.skills:
		if s is Dictionary and int(s.get("id", 0)) == skill_id:
			return _get_skill_data(skill_id, int(s.get("level", 1)))
	return {}

# 连击（skill_id=30001）：p1% 概率追加一击，伤害 = p2% * 攻击力计算
func _try_combo_strike(attacker: BattleUnit, target: BattleUnit, sf: SpriteFrames, has_atk_anim: bool) -> void:
	if attacker == null or target == null or attacker.is_dead or target.is_dead:
		return
	var sd := _find_skill(attacker, 30001)
	if sd.is_empty():
		return
	var prob: int = int(sd.get("p1", 0))
	if prob <= 0:
		return
	if (randi() % 100) >= prob:
		return
	var mult: float = float(int(sd.get("p2", 0))) / 100.0
	if mult <= 0.0:
		return
	# 飘 "连击!" 提示
	_spawn_skill_label(attacker, "连击!")
	# 再播一次攻击动画 + 应用追加伤害
	if has_atk_anim and is_instance_valid(attacker.sprite) and sf and sf.has_animation("attack"):
		attacker.sprite.play("attack")
	await get_tree().create_timer(0.4).timeout
	if not target.is_dead:
		_apply_damage(attacker, target, mult)
	if has_atk_anim and is_instance_valid(attacker.sprite):
		if attacker.sprite.animation == "attack" and attacker.sprite.is_playing():
			await attacker.sprite.animation_finished
		if is_instance_valid(attacker.sprite):
			var back := "alert" if sf and sf.has_animation("alert") else "idle"
			if sf and sf.has_animation(back):
				attacker.sprite.play(back)

# 反击（skill_id=30002）：目标在普攻命中后 p1% 概率反击攻击者，伤害 = p2% * 目标攻击力计算
func _try_counter_strike(attacker: BattleUnit, target: BattleUnit) -> void:
	if attacker == null or target == null or attacker.is_dead or target.is_dead:
		return
	var sd := _find_skill(target, 30002)
	if sd.is_empty():
		return
	var prob: int = int(sd.get("p1", 0))
	if prob <= 0:
		return
	if (randi() % 100) >= prob:
		return
	var mult: float = float(int(sd.get("p2", 0))) / 100.0
	if mult <= 0.0:
		return
	# 飘 "反击!" 提示
	_spawn_skill_label(target, "反击!")
	# 目标原地播一次攻击动画 + 对攻击者应用伤害
	var sf: SpriteFrames = null
	var has_atk_anim := false
	if is_instance_valid(target.sprite):
		sf = target.sprite.sprite_frames
		if sf and sf.has_animation("attack"):
			has_atk_anim = true
			target.sprite.play("attack")
	await get_tree().create_timer(0.4).timeout
	if not attacker.is_dead:
		_apply_damage(target, attacker, mult)
	if has_atk_anim and is_instance_valid(target.sprite):
		if target.sprite.animation == "attack" and target.sprite.is_playing():
			await target.sprite.animation_finished
		if is_instance_valid(target.sprite):
			var back := "alert" if sf and sf.has_animation("alert") else "idle"
			if sf and sf.has_animation(back):
				target.sprite.play(back)

# 攻防一体（skill_id=40001）：普攻命中后必定附加一次伤害，伤害 = 攻击者护甲 * p1%
func _try_armor_strike(attacker: BattleUnit, target: BattleUnit) -> void:
	if attacker == null or target == null or attacker.is_dead or target.is_dead:
		return
	var sd := _find_skill(attacker, 40001)
	if sd.is_empty():
		return
	var ratio: float = float(int(sd.get("p1", 0))) / 100.0
	if ratio <= 0.0:
		return
	var bonus: int = max(1, int(attacker.def * ratio))
	_spawn_skill_label(attacker, "盾击!")
	target.cur_hp = max(0, target.cur_hp - bonus)
	target.status_bar.update_hp(target.cur_hp)
	_spawn_damage_label(target, bonus, false, false)
	var dying := target.cur_hp <= 0
	if dying:
		target.is_dead = true
	target.play_hurt_then(dying)

# 鹰眼（skill_id=40002）：普攻有 p1% 概率本次无视目标闪避
func _try_eagle_eye(attacker: BattleUnit) -> bool:
	if attacker == null or attacker.is_dead:
		return false
	var sd := _find_skill(attacker, 40002)
	if sd.is_empty():
		return false
	var prob: int = int(sd.get("p1", 0))
	if prob <= 0:
		return false
	if (randi() % 100) >= prob:
		return false
	_spawn_skill_label(attacker, "鹰眼!")
	return true

func _spawn_skill_label(attacker: BattleUnit, text: String) -> void:
	if attacker == null or not is_instance_valid(attacker.root):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(160, 40)
	var start_pos := attacker.root.position + Vector2(-80, -150)
	lbl.position = start_pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 110
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size  = 30
	ls.font_color = Color(1.0, 0.85, 0.25)
	ls.outline_size  = 5
	ls.outline_color = Color(0.2, 0.05, 0, 1.0)
	lbl.label_settings = ls
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", start_pos.y - 40.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

func _spawn_damage_label(target: BattleUnit, dmg: int, is_miss: bool, is_crit: bool) -> void:
	if not is_instance_valid(target.root):
		return
	var lbl := Label.new()
	if is_miss:
		lbl.text = "MISS"
	elif is_crit:
		lbl.text = str(dmg) + "!!"
	else:
		lbl.text = str(dmg)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(140, 48)
	var start_pos := target.root.position + Vector2(-70, -110)
	lbl.position = start_pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	if is_crit:
		ls.font_size  = 38
		ls.font_color = Color(1.0, 0.35, 0.35)
	elif is_miss:
		ls.font_size  = 24
		ls.font_color = Color(0.85, 0.85, 0.85)
	else:
		ls.font_size  = 26
		ls.font_color = Color(1.0, 0.35, 0.35)
	ls.outline_size  = 4
	ls.outline_color = Color(0, 0, 0, 1.0)
	ls.shadow_size   = 3
	ls.shadow_color  = Color(0, 0, 0, 0.6)
	lbl.label_settings = ls
	add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", start_pos.y - 60.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

func _start_new_round() -> void:
	# 回合末结算（第一回合开始前不触发）
	if _round_number > 0:
		_resolve_end_of_round()
	# 清理上一回合的灵魂汲取标记
	_clear_drain_marks()
	var alive: Array = []
	for u in _battle_units:
		var unit := u as BattleUnit
		if not unit.is_dead:
			alive.append(unit)
	# 按出手速度从高到低排序
	alive.sort_custom(func(a, b): return a.spd > b.spd)
	_round_queue = alive
	_round_number += 1
	if is_instance_valid(_round_label):
		_round_label.text = "第 %d 回合" % _round_number
	# 回合开始结算：灵魂汲取等
	_resolve_start_of_round()

# 回合末统一结算：复苏（40003）等回合末效果
func _resolve_end_of_round() -> void:
	for u in _battle_units:
		var caster := u as BattleUnit
		if caster == null or caster.is_dead:
			continue
		_try_revive_heal(caster)

# 复苏（skill_id=40003）：每回合末，为同阵营 HP 百分比最低的存活单位回复 p1 点生命
func _try_revive_heal(caster: BattleUnit) -> void:
	var sd := _find_skill(caster, 40003)
	if sd.is_empty():
		return
	var heal: int = int(sd.get("p1", 0))
	if heal <= 0:
		return
	var target: BattleUnit = null
	var lowest_ratio: float = 2.0
	for u in _battle_units:
		var ally := u as BattleUnit
		if ally == null or ally.is_dead:
			continue
		if ally.is_enemy != caster.is_enemy:
			continue
		if ally.max_hp <= 0:
			continue
		if ally.cur_hp >= ally.max_hp:
			continue
		var ratio: float = float(ally.cur_hp) / float(ally.max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			target = ally
	if target == null:
		return
	var new_hp: int = min(target.max_hp, target.cur_hp + heal)
	var actual: int = new_hp - target.cur_hp
	if actual <= 0:
		return
	target.cur_hp = new_hp
	if is_instance_valid(target.status_bar):
		target.status_bar.update_hp(target.cur_hp)
	_spawn_skill_label(caster, "复苏!")
	_spawn_heal_label(target, actual)

func _spawn_heal_label(target: BattleUnit, amount: int) -> void:
	if target == null or not is_instance_valid(target.root):
		return
	var lbl := Label.new()
	lbl.text = "+" + str(amount)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(140, 48)
	var start_pos := target.root.position + Vector2(-70, -110)
	lbl.position = start_pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100
	var ls := LabelSettings.new()
	ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size  = 28
	ls.font_color = Color(0.45, 1.0, 0.45)
	ls.outline_size  = 4
	ls.outline_color = Color(0, 0, 0, 1.0)
	ls.shadow_size   = 3
	ls.shadow_color  = Color(0, 0, 0, 0.6)
	lbl.label_settings = ls
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", start_pos.y - 60.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
# 灵魂汲取（40004）
# ─────────────────────────────────────────────────────────────────────────────

func _clear_drain_marks() -> void:
	for u in _battle_units:
		var unit := u as BattleUnit
		if unit == null:
			continue
		unit.drain_sources.clear()
		if is_instance_valid(unit.drain_label):
			unit.drain_label.queue_free()
		unit.drain_label = null

func _resolve_start_of_round() -> void:
	for u in _battle_units:
		var caster := u as BattleUnit
		if caster == null or caster.is_dead:
			continue
		_try_soul_drain_mark(caster)

# 回合开始：从对方阵营存活单位中随机挑一个标记为汲取目标
func _try_soul_drain_mark(caster: BattleUnit) -> void:
	var sd := _find_skill(caster, 40004)
	if sd.is_empty():
		return
	var ratio: float = float(int(sd.get("p1", 0))) / 100.0
	if ratio <= 0.0:
		return
	var enemies: Array = []
	for u in _battle_units:
		var e := u as BattleUnit
		if e == null or e.is_dead:
			continue
		if e.is_enemy != caster.is_enemy:
			enemies.append(e)
	if enemies.is_empty():
		return
	var target: BattleUnit = enemies[randi() % enemies.size()]
	target.drain_sources.append({"caster": caster, "ratio": ratio})
	if not is_instance_valid(target.drain_label):
		_attach_drain_marker(target)

func _attach_drain_marker(target: BattleUnit) -> void:
	if not is_instance_valid(target.root):
		return
	var lbl := Label.new()
	lbl.text = "汲取"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(120, 32)
	lbl.position = Vector2(-60, -95)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 90
	var ls := LabelSettings.new()
	ls.font          = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size     = 22
	ls.font_color    = Color(0.85, 0.55, 1.0)
	ls.outline_size  = 4
	ls.outline_color = Color(0, 0, 0, 1.0)
	ls.shadow_size   = 3
	ls.shadow_color  = Color(0, 0, 0, 0.6)
	lbl.label_settings = ls
	target.root.add_child(lbl)
	target.drain_label = lbl

# 实际造成伤害后调用：对所有汲取此目标的施法者按比例回血
func _apply_drain(target: BattleUnit, dmg: int) -> void:
	if target == null or target.drain_sources.is_empty():
		return
	for src in target.drain_sources:
		var caster := src.get("caster") as BattleUnit
		if caster == null or caster.is_dead:
			continue
		var ratio: float = float(src.get("ratio", 0.0))
		var heal: int = int(round(float(dmg) * ratio))
		if heal <= 0:
			continue
		var new_hp: int = min(caster.max_hp, caster.cur_hp + heal)
		var actual: int = new_hp - caster.cur_hp
		if actual <= 0:
			continue
		caster.cur_hp = new_hp
		if is_instance_valid(caster.status_bar):
			caster.status_bar.update_hp(caster.cur_hp)
		_spawn_heal_label(caster, actual)


# ─────────────────────────────────────────────────────────────────────────────
# 野蛮冲撞（40005）
# ─────────────────────────────────────────────────────────────────────────────

# 普攻命中后调用：按 p1% 概率给目标上晕眩
func _try_brutal_stun(attacker: BattleUnit, target: BattleUnit) -> void:
	if attacker == null or target == null or target.is_dead:
		return
	if target.stunned:
		return
	var sd := _find_skill(attacker, 40005)
	if sd.is_empty():
		return
	var prob: int = int(sd.get("p1", 0))
	if prob <= 0:
		return
	if (randi() % 100) >= prob:
		return
	target.stunned = true
	_spawn_skill_label(attacker, "冲撞!")
	_attach_stun_marker(target)

func _clear_stun(target: BattleUnit) -> void:
	if target == null:
		return
	target.stunned = false
	if is_instance_valid(target.stun_label):
		target.stun_label.queue_free()
	target.stun_label = null

func _attach_stun_marker(target: BattleUnit) -> void:
	if not is_instance_valid(target.root):
		return
	if is_instance_valid(target.stun_label):
		target.stun_label.queue_free()
	var lbl := Label.new()
	lbl.text = "晕眩"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(120, 32)
	lbl.position = Vector2(-60, -125)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 90
	var ls := LabelSettings.new()
	ls.font          = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size     = 22
	ls.font_color    = Color(1.0, 0.9, 0.3)
	ls.outline_size  = 4
	ls.outline_color = Color(0, 0, 0, 1.0)
	ls.shadow_size   = 3
	ls.shadow_color  = Color(0, 0, 0, 0.6)
	lbl.label_settings = ls
	target.root.add_child(lbl)
	target.stun_label = lbl


func _check_battle_over() -> bool:
	var players_alive := false
	var enemies_alive := false
	for u in _battle_units:
		var unit := u as BattleUnit
		if unit.is_dead:
			continue
		if unit.is_enemy:
			enemies_alive = true
		else:
			players_alive = true

	if not enemies_alive:
		_end_battle(true)
		return true
	if not players_alive:
		_end_battle(false)
		return true
	return false

func _end_battle(victory: bool) -> void:
	_battle_over = true
	if victory:
		_record_level_cleared()
	var vp := get_viewport_rect().size
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	var title := "胜利！" if victory else "战败..."
	var title_color := Color(1.0, 0.9, 0.2) if victory else Color(1.0, 0.3, 0.3)

	var panel_w := 420.0
	var panel_h := 200.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.18, 0.95)
	style.set_corner_radius_all(16)
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_color = title_color
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size  = 12

	var panel := Panel.new()
	panel.size     = Vector2(panel_w, panel_h)
	panel.position = (vp - Vector2(panel_w, panel_h)) * 0.5
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size     = Vector2(panel_w, 90.0)
	title_lbl.position = panel.position
	var tls := LabelSettings.new()
	tls.font       = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	tls.font_size  = 52
	tls.font_color = title_color
	tls.outline_size  = 4
	tls.outline_color = Color(0, 0, 0, 1.0)
	title_lbl.label_settings = tls
	ui.add_child(title_lbl)

	var back_btn := _make_button("返回", panel.position + Vector2((panel_w - 120) * 0.5, 110.0), Vector2(120, 52))
	ui.add_child(back_btn.panel)
	ui.add_child(back_btn.label)
	back_btn.label.gui_input.connect(_on_exit_input)

	if victory:
		var next_id := _next_level_id_str()
		if not next_id.is_empty():
			# 有下一关：把"返回"挪到左半边，右边加"下一关"
			var btn_w := 120.0
			var btn_h := 52.0
			var gap := 30.0
			var x0 := panel.position.x + (panel_w - (btn_w * 2 + gap)) * 0.5
			var y := panel.position.y + 110.0
			back_btn.panel.position = Vector2(x0, y)
			back_btn.label.position = Vector2(x0, y)
			var next_btn := _make_button("下一关", Vector2(x0 + btn_w + gap, y), Vector2(btn_w, btn_h))
			ui.add_child(next_btn.panel)
			ui.add_child(next_btn.label)
			next_btn.label.gui_input.connect(_on_next_level_input.bind(next_id))

# ─────────────────────────────────────────────────────────────────────────────
# 阵型选择模式
# ─────────────────────────────────────────────────────────────────────────────

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
	var team_ids   := _get_team_ids()

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
		@warning_ignore("integer_division")
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

	var prev_btn := _make_arrow_button("<", Vector2(bar_x + 10, bar_y + 5), Vector2(44, 48))
	ui.add_child(prev_btn.panel)
	ui.add_child(prev_btn.label)
	prev_btn.label.gui_input.connect(_on_formation_prev)

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

	var next_btn := _make_arrow_button(">", Vector2(bar_x + bar_w - 54, bar_y + 5), Vector2(44, 48))
	ui.add_child(next_btn.panel)
	ui.add_child(next_btn.label)
	next_btn.label.gui_input.connect(_on_formation_next)

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

func _record_level_cleared() -> void:
	var save_path := "user://savegame.json"
	var level_id_str: String = String(GlobalConfig.get_runtime("level_id"))
	if not level_id_str.is_valid_int():
		return
	var cleared_id := int(level_id_str)
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary:
				data = parsed

	# 仅当首次通关时累加经验，避免重复刷
	var prev: int = int(data.get("cleared_level", 0))
	var first_clear: bool = cleared_id > prev
	if first_clear:
		data["cleared_level"] = cleared_id
		_grant_exp_to_team(data, cleared_id)

	var wf := FileAccess.open(save_path, FileAccess.WRITE)
	if wf == null:
		return
	wf.store_string(JSON.stringify(data))
	wf.close()

func _grant_exp_to_team(data: Dictionary, cleared_id: int) -> void:
	var levels_data := _load_levels_table()
	var lid_str := str(cleared_id)
	if not levels_data.has(lid_str):
		return
	var exp_gain: int = int(levels_data[lid_str].get("exp", 0))
	if exp_gain <= 0:
		return
	var team_ids := _get_team_ids()
	if team_ids.is_empty():
		return
	var level_up := _load_level_up_table()
	var roles_state: Dictionary = {}
	if data.has("roles") and data["roles"] is Dictionary:
		roles_state = data["roles"]
	for rid in team_ids:
		var st: Dictionary = roles_state.get(rid, {})
		var lv: int = int(st.get("level", 1))
		var cur_exp: int = int(st.get("exp", 0)) + exp_gain
		var promoted := _apply_level_up(lv, cur_exp, level_up)
		st["level"] = promoted.level
		st["exp"] = promoted.exp
		if not st.has("star"):
			st["star"] = 1
		roles_state[rid] = st
	data["roles"] = roles_state

# 把 (level, exp) 按 level_up.txt 推进到稳定状态。max_exp <= 0 视为已满级。
func _apply_level_up(level: int, cur_exp: int, level_up: Dictionary) -> Dictionary:
	var lv: int = max(level, 1)
	var ex: int = max(cur_exp, 0)
	while true:
		var max_exp: int = int(level_up.get(lv, 0))
		if max_exp <= 0:
			ex = 0  # 满级，经验清零
			break
		if ex < max_exp:
			break
		ex -= max_exp
		lv += 1
	return {"level": lv, "exp": ex}

func _load_level_up_table() -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(LEVEL_UP_TABLE_PATH, FileAccess.READ)
	if not file:
		return result
	var text := file.get_as_text()
	file.close()
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return result
	for i in range(1, raw.size()):
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 2:
			continue
		var lv_s: String = (parts[0] as String).strip_edges()
		var exp_s: String = (parts[1] as String).strip_edges()
		if not lv_s.is_valid_int():
			continue
		result[int(lv_s)] = int(exp_s) if exp_s.is_valid_int() else 0
	return result

# 技能表：返回 {skill_id_int: {level_int: {desc, p1, p2, upgrade_cost, icon}}}
var _skill_table_cache: Dictionary = {}
func _load_skill_table() -> Dictionary:
	if not _skill_table_cache.is_empty():
		return _skill_table_cache
	var result: Dictionary = {}
	var file := FileAccess.open(SKILL_TABLE_PATH, FileAccess.READ)
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
		var entry: Dictionary = {}
		for j in headers.size():
			entry[headers[j]] = parts[j]
		var sid_s: String = String(entry.get("skill_id", "")).strip_edges()
		var lv_s: String = String(entry.get("level", "")).strip_edges()
		if not sid_s.is_valid_int() or not lv_s.is_valid_int():
			continue
		var sid := int(sid_s)
		var lv := int(lv_s)
		if not result.has(sid):
			result[sid] = {}
		result[sid][lv] = {
			"desc":         String(entry.get("desc", "")),
			"p1":           int(entry.get("param1", "0")),
			"p2":           int(entry.get("param2", "0")),
			"upgrade_cost": int(entry.get("upgrade_cost", "0")),
			"icon":         String(entry.get("icon", "")),
		}
	_skill_table_cache = result
	return result

func _get_skill_data(sid: int, lv: int) -> Dictionary:
	var table := _load_skill_table()
	if not table.has(sid):
		return {}
	var levels: Dictionary = table[sid]
	if levels.has(lv):
		return levels[lv]
	# 找不到当前级，退到该技能最高已配置的级别
	var keys := levels.keys()
	keys.sort()
	if keys.is_empty():
		return {}
	return levels[keys[-1]]

# ─────────────────────────────────────────────────────────────────────────────
# 放置角色并构建 BattleUnit
# ─────────────────────────────────────────────────────────────────────────────

func _place_battle_roles(vp: Vector2) -> void:
	var cell_w := vp.x / GRID_COLS
	var cell_h := vp.y / GRID_ROWS

	var roles_data := _load_roles_table()
	var attrs_data := _load_attrs_table()

	var formation_id := int(GlobalConfig.get_runtime("formation_id"))
	if formation_id <= 0:
		formation_id = 1

	var formations := _load_formations_table()
	var formation_positions: Array = []
	for f in formations:
		if int(f["id"]) == formation_id:
			formation_positions = f["positions"]
			break

	var team_ids := _get_team_ids()
	var hp_tex   := load("res://asserts/image/ui/hp_bar.png") as Texture2D
	var mp_tex   := load("res://asserts/image/ui/mp_bar.png") as Texture2D
	var font     := load("res://asserts/fonts/ZCOOLKuaiLe.ttf") as Font

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

		var root := Node2D.new()
		root.position = Vector2(
			(col - 1) * cell_w + cell_w * 0.5,
			(row - 1) * cell_h + cell_h * 0.5
		)
		add_child(root)

		var sprite := _build_animated_sprite(rd)
		sprite.scale *= 1.1
		root.add_child(sprite)

		var attrs := _calc_attrs(rid, rd, attrs_data)
		var bar := RoleStatusBar.new(
			attrs.hp, attrs.hp,
			hp_tex, mp_tex, font,
			BAR_W, BAR_H, HP_OFFSET, MP_OFFSET
		)
		root.add_child(bar)

		var unit := BattleUnit.new()
		unit.rid        = rid
		unit.is_enemy   = false
		unit.cur_hp     = attrs.hp
		unit.max_hp     = attrs.hp
		unit.atk        = attrs.atk
		unit.def        = attrs.def
		unit.spd        = attrs.spd
		unit.crit       = attrs.crit
		unit.dodge      = attrs.dodge
		unit.sprite     = sprite
		unit.status_bar = bar
		unit.root       = root
		unit.rd         = rd
		unit.skills     = _get_role_skills(rid)
		_battle_units.append(unit)

func _place_enemy_roles(vp: Vector2) -> void:
	var level_id: String = String(GlobalConfig.get_runtime("level_id"))
	if level_id.is_empty():
		return
	var levels_data := _load_levels_table()
	if not levels_data.has(level_id):
		return
	var level: Dictionary = levels_data[level_id]
	var monster_ids: Array = level["monster_ids"]
	if monster_ids.is_empty():
		return

	var formations := _load_formations_table()
	var formation_positions: Array = []
	for f in formations:
		if int(f["id"]) == int(level["formation_id"]):
			formation_positions = f["positions"]
			break
	if formation_positions.is_empty():
		return

	var roles_data := _load_roles_table()
	var attrs_data := _load_attrs_table()
	var monster_lv: int = int(level.get("monster_level", 1))
	var cell_w := vp.x / GRID_COLS
	var cell_h := vp.y / GRID_ROWS
	var hp_tex := load("res://asserts/image/ui/hp_bar.png") as Texture2D
	var mp_tex := load("res://asserts/image/ui/mp_bar.png") as Texture2D
	var font   := load("res://asserts/fonts/ZCOOLKuaiLe.ttf") as Font

	for i in mini(monster_ids.size(), formation_positions.size()):
		var rc: Vector2 = formation_positions[i]
		if rc == Vector2.ZERO:
			continue
		var row := int(rc.x)
		var col := mirror_col(int(rc.y))
		var rid: String = monster_ids[i]
		if not roles_data.has(rid):
			continue
		var rd: Dictionary = roles_data[rid]

		var root := Node2D.new()
		root.position = Vector2(
			(col - 1) * cell_w + cell_w * 0.5,
			(row - 1) * cell_h + cell_h * 0.5
		)
		add_child(root)

		var sprite := _build_animated_sprite(rd)
		root.add_child(sprite)

		var attrs := _calc_attrs(rid, rd, attrs_data, monster_lv)
		var bar := RoleStatusBar.new(
			attrs.hp, attrs.hp,
			hp_tex, mp_tex, font,
			BAR_W, BAR_H, HP_OFFSET, MP_OFFSET
		)
		root.add_child(bar)

		var unit := BattleUnit.new()
		unit.rid        = rid
		unit.is_enemy   = true
		unit.cur_hp     = attrs.hp
		unit.max_hp     = attrs.hp
		unit.atk        = attrs.atk
		unit.def        = attrs.def
		unit.spd        = attrs.spd
		unit.crit       = attrs.crit
		unit.dodge      = attrs.dodge
		unit.sprite     = sprite
		unit.status_bar = bar
		unit.root       = root
		unit.rd         = rd
		_battle_units.append(unit)

# 构建带 idle/alert/attack/dead 四组动画的 AnimatedSprite2D
func _build_animated_sprite(rd: Dictionary) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()

	var anim_defs := [
		["idle",   rd.idle_sheet,   rd.idle_frames,   rd.idle_anim_fps],
		["alert",  rd.alert_sheet,  rd.alert_frames,  rd.alert_anim_fps],
		["attack", rd.attack_sheet, rd.attack_frames, rd.attack_anim_fps],
		["hurt",   rd.hurt_sheet,   rd.hurt_frames,   rd.hurt_anim_fps],
		["dead",   rd.dead_sheet,   rd.dead_frames,   rd.dead_anim_fps],
	]

	var first_valid_anim := "idle"
	for def in anim_defs:
		var anim_name: String = def[0]
		var path: String      = def[1]
		var frames: int       = def[2]
		var fps: float        = def[3]
		if path.is_empty():
			continue
		var tex := load(path) as Texture2D
		if not tex:
			continue
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		# idle/alert 循环，attack/dead 只播一次
		sf.set_animation_loop(anim_name, anim_name == "idle" or anim_name == "alert")
		@warning_ignore("integer_division")
		var fw := tex.get_width() / frames
		var fh := tex.get_height()
		for k in range(frames):
			var at := AtlasTexture.new()
			at.atlas  = tex
			at.region = Rect2(k * fw, 0, fw, fh)
			sf.add_frame(anim_name, at)
		if first_valid_anim == "idle" and anim_name == "alert":
			first_valid_anim = "alert"

	if not sf.has_animation("idle"):
		sf.add_animation("idle")

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.scale         = Vector2(rd.idle_scale, rd.idle_scale)
	sprite.flip_h        = bool(rd.get("flip_h", false))
	sprite.animation     = first_valid_anim
	sprite.play(first_valid_anim)
	return sprite

# ─────────────────────────────────────────────────────────────────────────────
# 属性计算：init + (lv-1)*lv_bonus + star*star_bonus
# ─────────────────────────────────────────────────────────────────────────────

func _calc_attrs(rid: String, rd: Dictionary, attrs_data: Dictionary, override_lv: int = -1) -> Dictionary:
	var lv   := int(rd.get("init_level", 1)) if override_lv <= 0 else override_lv
	var star := int(rd.get("init_star",  1))
	if not attrs_data.has(rid):
		return {hp=500, atk=80, def=30, spd=80, crit=500, dodge=300}
	var a: Dictionary = attrs_data[rid]
	return {
		"hp":    a.init_hp    + (lv - 1) * a.lv_hp    + star * a.star_hp,
		"atk":   a.init_atk   + (lv - 1) * a.lv_atk   + star * a.star_atk,
		"def":   a.init_def   + (lv - 1) * a.lv_def   + star * a.star_def,
		"spd":   a.init_speed + (lv - 1) * a.lv_speed + star * a.star_speed,
		"crit":  a.init_crit  + (lv - 1) * a.lv_crit  + star * a.star_crit,
		"dodge": a.init_dodge + (lv - 1) * a.lv_dodge + star * a.star_dodge,
	}

# ─────────────────────────────────────────────────────────────────────────────
# 数据加载
# ─────────────────────────────────────────────────────────────────────────────

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
			"idle_sheet":      String(entry.get("idle_sheet",      "")),
			"idle_frames":     int(entry.get("idle_frames",     "1")),
			"idle_scale":      float(entry.get("idle_scale",     "0.27")),
			"idle_anim_fps":   float(entry.get("idle_anim_fps",  "6.0")),
			"alert_sheet":     String(entry.get("alert_sheet",    "")),
			"alert_frames":    int(entry.get("alert_frames",    "1")),
			"alert_anim_fps":  float(entry.get("alert_anim_fps", "6.0")),
			"attack_sheet":    String(entry.get("attack_sheet",   "")),
			"attack_frames":   int(entry.get("attack_frames",   "1")),
			"attack_anim_fps": float(entry.get("attack_anim_fps","12.0")),
			"hurt_sheet":      String(entry.get("hurt_sheet",     "")),
			"hurt_frames":     int(_default_if_empty(entry.get("hurt_frames", "1"), "1")),
			"hurt_anim_fps":   float(_default_if_empty(entry.get("hurt_anim_fps","12.0"), "12.0")),
			"dead_sheet":      String(entry.get("dead_sheet",     "")),
			"dead_frames":     int(entry.get("dead_frames",     "1")),
			"dead_anim_fps":   float(entry.get("dead_anim_fps",  "12.0")),
			"init_level":      int(entry.get("init_level",      "1")),
			"init_star":       int(entry.get("init_star",       "1")),
			"default_skill":   int(entry.get("default_skill",   "0")),
			"flip_h":          int(entry.get("flip_h",          "0")) != 0,
		}
	return result

func _load_attrs_table() -> Dictionary:
	var result := {}
	var file := FileAccess.open(ROLE_ATTRS_TABLE_PATH, FileAccess.READ)
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
			"init_atk":   int(entry.get("init_atk",   "50")),
			"init_def":   int(entry.get("init_def",   "20")),
			"init_hp":    int(entry.get("init_hp",    "500")),
			"init_speed": int(entry.get("init_speed", "80")),
			"init_crit":  int(entry.get("init_crit",  "500")),
			"init_dodge": int(entry.get("init_dodge", "300")),
			"lv_atk":     int(entry.get("lv_atk",     "5")),
			"lv_def":     int(entry.get("lv_def",     "2")),
			"lv_hp":      int(entry.get("lv_hp",      "50")),
			"lv_speed":   int(entry.get("lv_speed",   "2")),
			"lv_crit":    int(entry.get("lv_crit",    "50")),
			"lv_dodge":   int(entry.get("lv_dodge",   "50")),
			"star_atk":   int(entry.get("star_atk",   "20")),
			"star_def":   int(entry.get("star_def",   "10")),
			"star_hp":    int(entry.get("star_hp",    "200")),
			"star_speed": int(entry.get("star_speed", "10")),
			"star_crit":  int(entry.get("star_crit",  "200")),
			"star_dodge": int(entry.get("star_dodge", "100")),
		}
	return result

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
		result.append({"id": int(parts[0]), "name": String(parts[1]), "positions": positions})
	return result

func _load_levels_table() -> Dictionary:
	var result := {}
	var file := FileAccess.open(LEVELS_TABLE_PATH, FileAccess.READ)
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
		var lid: String = String(entry.get("level_id", ""))
		if lid.is_empty():
			continue
		var monster_ids: Array[String] = []
		for piece in String(entry.get("monster_ids", "")).split(","):
			var s: String = (piece as String).strip_edges()
			if not s.is_empty() and s != "0":
				monster_ids.append(s)
		result[lid] = {
			"name":         String(entry.get("name", "")),
			"monster_ids":  monster_ids,
			"monster_level": int(entry.get("monster_level", "1")),
			"formation_id": int(entry.get("formation_id", "1")),
			"exp":          int(entry.get("exp", "0")),
		}
	return result

func _get_team_ids() -> Array:
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
	var defaults := GlobalConfig.get_str("default_owned_roles", "")
	var result: Array[String] = []
	for piece in defaults.split(","):
		var s: String = (piece as String).strip_edges()
		if not s.is_empty():
			result.append(s)
	return result

# 从存档读取角色已学技能；找不到则回退到默认技能。槽位数 = 角色星数
func _get_role_skills(rid: String) -> Array:
	var star: int = 1
	var skills_raw: Array = []
	var save_path := "user://savegame.json"
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary and parsed.has("roles") and parsed["roles"] is Dictionary:
				var rs: Dictionary = parsed["roles"]
				if rs.has(rid) and rs[rid] is Dictionary:
					var rd: Dictionary = rs[rid]
					star = int(rd.get("star", 1))
					if rd.has("skills") and rd["skills"] is Array:
						for s in rd["skills"]:
							if s is Dictionary and int(s.get("id", 0)) > 0:
								skills_raw.append({"id": int(s.get("id", 0)), "level": int(s.get("level", 1))})
	if skills_raw.is_empty():
		for s in DEFAULT_SKILLS:
			skills_raw.append({"id": int(s.id), "level": int(s.level)})
	var slots: int = max(1, star)
	if skills_raw.size() > slots:
		skills_raw.resize(slots)
	return skills_raw

# ─────────────────────────────────────────────────────────────────────────────
# 工具
# ─────────────────────────────────────────────────────────────────────────────

static func mirror_col(col: int) -> int:
	return GRID_COLS + 1 - col

static func _default_if_empty(v, default_str: String) -> String:
	var s := String(v)
	return default_str if s.is_empty() else s

func _on_exit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main := load(MAIN_SCENE_PATH) as PackedScene
		SceneTransition.change_to(main)

func _on_next_level_input(event: InputEvent, next_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if next_id.is_empty():
			return
		GlobalConfig.set_runtime("scene_mode", "battle")
		GlobalConfig.set_runtime("level_id", next_id)
		var scene := load(BATTLE_SCENE_PATH) as PackedScene
		SceneTransition.change_to(scene)

func _next_level_id_str() -> String:
	var cur_str: String = String(GlobalConfig.get_runtime("level_id"))
	if not cur_str.is_valid_int():
		return ""
	var cur := int(cur_str)
	var levels_data := _load_levels_table()
	var ids: Array = []
	for k in levels_data.keys():
		var s := String(k)
		if s.is_valid_int():
			ids.append(int(s))
	if ids.is_empty():
		return ""
	ids.sort()
	for lid in ids:
		if lid > cur:
			return str(lid)
	return ""

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

# ─────────────────────────────────────────────────────────────────────────────
# 血条节点
# ─────────────────────────────────────────────────────────────────────────────

class RoleStatusBar extends Node2D:
	var cur_hp : int
	var max_hp : int
	var hp_tex : Texture2D   # 前景（红，剩余血量）
	var bg_tex : Texture2D   # 底色（蓝，已损失部分）
	var font   : Font
	var bar_w  : float
	var bar_h  : float
	var bar_off: Vector2

	func _init(mhp:int, _unused_mmp:int, htex:Texture2D, btex:Texture2D,
			   fnt:Font, bw:float, bh:float, hoff:Vector2, _unused_moff:Vector2) -> void:
		cur_hp = mhp; max_hp = mhp
		hp_tex = htex; bg_tex = btex
		font = fnt
		bar_w = bw; bar_h = bh
		bar_off = hoff

	func update_hp(new_hp: int) -> void:
		cur_hp = new_hp
		queue_redraw()

	func _draw() -> void:
		var ratio: float = 0.0 if max_hp <= 0 else clampf(float(cur_hp) / float(max_hp), 0.0, 1.0)
		var r := int(bar_h * 0.5)  # 半圆端头

		# 底色：灰色圆角
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.35, 0.35, 0.35, 0.9)
		bg_style.set_corner_radius_all(r)
		draw_style_box(bg_style, Rect2(bar_off, Vector2(bar_w, bar_h)))

		# 前景：红色，左端圆角，右端仅满血时圆角
		if ratio > 0.0:
			var fg_style := StyleBoxFlat.new()
			fg_style.bg_color = Color(0.68, 0.08, 0.08, 1.0)
			fg_style.set_corner_radius_all(0)
			fg_style.set_corner_radius(CORNER_TOP_LEFT, r)
			fg_style.set_corner_radius(CORNER_BOTTOM_LEFT, r)
			if ratio >= 0.99:
				fg_style.set_corner_radius(CORNER_TOP_RIGHT, r)
				fg_style.set_corner_radius(CORNER_BOTTOM_RIGHT, r)
			draw_style_box(fg_style, Rect2(bar_off, Vector2(bar_w * ratio, bar_h)))

		# 边框：圆角，宽度 2px
		var border_style := StyleBoxFlat.new()
		border_style.draw_center = false
		border_style.set_corner_radius_all(r)
		border_style.border_width_top    = 2
		border_style.border_width_bottom = 2
		border_style.border_width_left   = 2
		border_style.border_width_right  = 2
		border_style.border_color = Color(0.85, 0.68, 0.15, 1.0)
		draw_style_box(border_style, Rect2(bar_off, Vector2(bar_w, bar_h)))

		# 数值文本
		var txt := "%d/%d" % [cur_hp, max_hp]
		var font_size := 8
		var txt_size  := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var txt_pos   := bar_off + Vector2((bar_w - txt_size.x) * 0.5, bar_h * 0.5 + txt_size.y * 0.35)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx != 0 or dy != 0:
					draw_string(font, txt_pos + Vector2(dx, dy), txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
		draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 1))

# ─────────────────────────────────────────────────────────────────────────────
# 战斗单位数据
# ─────────────────────────────────────────────────────────────────────────────

class BattleUnit:
	var rid:        String
	var is_enemy:   bool = false
	var is_dead:    bool = false
	var cur_hp:     int  = 0
	var max_hp:     int  = 0
	var atk:        int  = 0
	var def:        int  = 0
	var spd:        int  = 0
	var crit:       int  = 0   # 万分比
	var dodge:      int  = 0   # 万分比
	var sprite:     AnimatedSprite2D = null
	var status_bar: RoleStatusBar   = null
	var root:       Node2D = null
	var rd:         Dictionary = {}
	var skills:     Array = []  # [{id:int, level:int}]
	# 灵魂汲取（40004）：本回合作为标记目标时，所有汲取者引用 + 汲取百分比；以及头顶飘字标签
	var drain_sources: Array = []  # [{caster: BattleUnit, ratio: float}]
	var drain_label:   Label = null
	# 野蛮冲撞（40005）：晕眩状态及头顶标签
	var stunned:    bool  = false
	var stun_label: Label = null

	# 播动画；attack 结束后自动回 alert/idle
	func play_anim(anim_name: String) -> void:
		if not is_instance_valid(sprite):
			return
		var sf: SpriteFrames = sprite.sprite_frames
		if not sf.has_animation(anim_name):
			return
		sprite.play(anim_name)
		if anim_name == "attack":
			if not sprite.animation_finished.is_connected(_on_attack_finished):
				sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

	func _on_attack_finished() -> void:
		if not is_instance_valid(sprite):
			return
		var sf: SpriteFrames = sprite.sprite_frames
		var back := "alert" if sf.has_animation("alert") else "idle"
		if sf.has_animation(back):
			sprite.play(back)

	# 受击：有 hurt 动画就播一遍再接 dead/alert；没有就直接接
	func play_hurt_then(dying: bool) -> void:
		if not is_instance_valid(sprite):
			return
		var sf: SpriteFrames = sprite.sprite_frames
		if sf and sf.has_animation("hurt"):
			sprite.play("hurt")
			var s := sprite
			sprite.animation_finished.connect(func():
				_after_hurt(s, dying)
			, CONNECT_ONE_SHOT)
		else:
			_after_hurt(sprite, dying)

	func _after_hurt(s: AnimatedSprite2D, dying: bool) -> void:
		if not is_instance_valid(s):
			return
		var sf: SpriteFrames = s.sprite_frames
		if dying:
			if sf and sf.has_animation("dead"):
				s.play("dead")
		else:
			var back := "alert" if sf and sf.has_animation("alert") else "idle"
			if sf and sf.has_animation(back):
				s.play(back)

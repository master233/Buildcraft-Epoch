extends Node2D

const MAIN_SCENE_PATH       := "res://scenes/Main.tscn"
const BATTLE_SCENE_PATH     := "res://scenes/BattleScene.tscn"
const ROLES_TABLE_PATH      := "res://asserts/table/roles.txt"
const ROLE_ATTRS_TABLE_PATH := "res://asserts/table/role_attrs.txt"
const FORMATIONS_TABLE_PATH := "res://asserts/table/formations.txt"
const LEVELS_TABLE_PATH     := "res://asserts/table/levels.txt"
const LEVEL_UP_TABLE_PATH   := "res://asserts/table/level_up.txt"
const SKILL_TABLE_PATH      := "res://asserts/table/skill.txt"
const SKILL_UPGRADE_COST_PATH := "res://asserts/table/skill_upgrade_cost.txt"
const FORMATION_BONUS_PATH   := "res://asserts/table/formation_bonus.txt"
const EQUIPMENT_TABLE_PATH   := "res://asserts/table/equipment.txt"
const MONSTER_TAUNTS_PATH    := "res://asserts/table/monster_taunts.txt"
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
var _formation_team_ids: Array = []
var _drag_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_original_pos: Vector2 = Vector2.ZERO

# 战斗状态
var _battle_units: Array = []   # Array of BattleUnit（玩家+敌方）
var _battle_over: bool = false
var _action_timer: float = 0.0
var _round_queue: Array = []    # 当前回合剩余待行动单位（按 spd 降序）
var _round_number: int = 0
var _round_label: Label = null
var _speed_btn_label: Label = null
var _battle_speed: int = 1
var _acting: bool = false       # 正在演出某单位行动序列
var _taunt_texts: Array = []    # 怪物嘲讽台词

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
		var formation_bgm := AudioStreamPlayer.new()
		formation_bgm.stream = load("res://asserts/audio/bg1.ogg")
		formation_bgm.volume_db = -3.0
		formation_bgm.autoplay = true
		add_child(formation_bgm)
		_build_formation_mode(vp)
	else:
		# 战斗背景音乐（仅战斗模式播放）
		var battle_bgm := AudioStreamPlayer.new()
		battle_bgm.stream = load("res://asserts/audio/battle.ogg")
		battle_bgm.volume_db = -3.0
		battle_bgm.autoplay = true
		add_child(battle_bgm)
		_load_taunt_texts()
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
		_build_speed_button(ui, vp)

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

# 战斗速度按钮：默认 1x，点击切换 1x/2x；通过 Engine.time_scale 全局加速
func _build_speed_button(ui: CanvasLayer, vp: Vector2) -> void:
	_battle_speed = _load_battle_speed()
	Engine.time_scale = float(_battle_speed)
	var btn := _make_button("速度 x%d" % _battle_speed, Vector2(vp.x - 240, 16), Vector2(112, 44))
	ui.add_child(btn.panel)
	ui.add_child(btn.label)
	_speed_btn_label = btn.label
	btn.label.gui_input.connect(_on_speed_btn_input)

func _on_speed_btn_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_battle_speed = 2 if _battle_speed == 1 else 1
	Engine.time_scale = float(_battle_speed)
	if is_instance_valid(_speed_btn_label):
		_speed_btn_label.text = "速度 x%d" % _battle_speed
	_save_battle_speed(_battle_speed)

func _load_battle_speed() -> int:
	var save_path := "user://savegame.json"
	if not FileAccess.file_exists(save_path):
		return 1
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return 1
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return 1
	var spd: int = int(parsed.get("battle_speed", 1))
	return 2 if spd == 2 else 1

func _save_battle_speed(spd: int) -> void:
	var save_path := "user://savegame.json"
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary:
				data = parsed
	data["battle_speed"] = spd
	var wf := FileAccess.open(save_path, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(data))
		wf.close()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

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

	# 当前回合行动队列空了，开新回合（异步，期间 _acting 标记防止重入）
	if _round_queue.is_empty():
		_acting = true
		await _start_new_round()
		_acting = false
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

	# 找对方阵营存活的随机目标（隐身单位不可被选中，除非攻击者自身有真视）
	var attacker_has_sight := not _find_skill(attacker, 30010).is_empty()
	var targets: Array = []
	for u in _battle_units:
		var candidate := u as BattleUnit
		if not candidate.is_dead and candidate.is_enemy != attacker.is_enemy:
			if candidate.stealth_rounds > 0 and not attacker_has_sight:
				continue
			targets.append(candidate)
	if targets.is_empty():
		_acting = false
		return
	var target := _weighted_target_pick(targets) as BattleUnit

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

	# 1.5) 守护（30003）：队友普攻被命中前，有几率替队友分担伤害；触发则移动到队友身旁
	var guard := _try_protect_guard(target, attacker)
	var protector: BattleUnit = null
	var protector_origin: Vector2 = Vector2.ZERO
	var protector_origin_z: int = 0
	var share_ratio: float = 0.0
	if not guard.is_empty():
		protector = guard["protector"]
		share_ratio = guard["share"]
		_spawn_skill_label(protector, _skill_name(30003) + "!")
		protector_origin = protector.root.position
		protector_origin_z = protector.root.z_index
		protector.root.z_index = 9
		var pdest: Vector2 = target.root.position + Vector2(-off_x, 0)
		var tw_p := create_tween()
		tw_p.tween_property(protector.root, "position", pdest, MOVE_IN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw_p.finished

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
	var hit: bool
	if protector != null:
		hit = _apply_damage(attacker, target, 1.0 - share_ratio, ignore_dodge)
		if not protector.is_dead:
			_apply_damage(attacker, protector, share_ratio, ignore_dodge)
	else:
		hit = _apply_damage(attacker, target, 1.0, ignore_dodge)
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

	# 2.7) 追击（30005）：本次普攻击杀目标后，可对随机存活敌人继续追击；继续击杀则重复
	if target.is_dead and not attacker.is_dead:
		await _try_pursue_strike(attacker, sf, has_atk_anim, off_x)

	# 3) 退回原位
	if is_instance_valid(atk_root):
		var tw_out := create_tween()
		tw_out.tween_property(atk_root, "position", origin, MOVE_OUT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_out.finished
		if is_instance_valid(atk_root):
			atk_root.z_index = origin_z

	# 3.5) 守护者回到原位
	if protector != null and is_instance_valid(protector.root) and not protector.is_dead:
		var tw_pb := create_tween()
		tw_pb.tween_property(protector.root, "position", protector_origin, MOVE_OUT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw_pb.finished
		if is_instance_valid(protector.root):
			protector.root.z_index = protector_origin_z

	_check_battle_over()
	_acting = false

func _apply_damage(attacker: BattleUnit, target: BattleUnit, dmg_mult: float = 1.0, ignore_dodge: bool = false) -> bool:
	# 暴击（30004）：本次普攻额外提升 p1% 暴击率，暴击伤害为 p2%
	var crit_chance: int = attacker.crit
	var crit_mult: float = 1.5
	var crit_sd := _find_skill(attacker, 30004)
	if not crit_sd.is_empty():
		crit_chance += int(crit_sd.get("p1", 0)) * 100
		var p2: int = int(crit_sd.get("p2", 0))
		if p2 > 0:
			crit_mult = float(p2) / 100.0
	var is_crit := (randi() % 10000) < crit_chance
	# 冷静（30013）：攻击有嘲讽的目标时无视 p1% 防御
	var effective_def: int = target.def
	if not _find_skill(target, 30012).is_empty():
		var calm_sd := _find_skill(attacker, 30013)
		if not calm_sd.is_empty():
			var ignore_pct: float = float(int(calm_sd.get("p1", 0))) / 100.0
			effective_def = int(float(target.def) * (1.0 - ignore_pct))
			_spawn_skill_label(attacker, _skill_name(30013) + "!")
	var dmg_base: int = max(1, attacker.atk - effective_def)
	# 隐身（30009）：处于隐身状态时攻击伤害按 stealth_mult 乘算
	var stealth_mul: float = 1.0
	if attacker.stealth_rounds > 0:
		stealth_mul = attacker.stealth_mult
	# 真视（30010）：攻击隐身目标时额外造成 p1% 伤害
	var true_sight_bonus: float = 0.0
	if target.stealth_rounds > 0:
		var ts_sd := _find_skill(attacker, 30010)
		if not ts_sd.is_empty():
			true_sight_bonus = float(int(ts_sd.get("p1", 0))) / 100.0
	var dmg := int(dmg_base * (crit_mult if is_crit else 1.0) * dmg_mult * stealth_mul * (1.0 + true_sight_bonus))
	# 嘲讽（30012）：减伤 p2%
	var taunt_sd := _find_skill(target, 30012)
	if not taunt_sd.is_empty():
		var reduce: float = float(int(taunt_sd.get("p2", 0))) / 100.0
		dmg = int(float(dmg) * (1.0 - reduce))
	dmg = max(1, dmg)
	var is_miss := false
	# 闪避（30006）：被普攻时额外提升 p1% 闪避率
	var dodge_chance: int = target.dodge
	var dodge_sd := _find_skill(target, 30006)
	if not dodge_sd.is_empty():
		dodge_chance += int(dodge_sd.get("p1", 0)) * 100
	if not ignore_dodge and (randi() % 10000) < dodge_chance:
		dmg = 0
		is_miss = true
	target.cur_hp = max(0, target.cur_hp - dmg)
	target.status_bar.update_hp(target.cur_hp)
	_spawn_damage_label(target, dmg, is_miss, is_crit)
	if is_miss:
		return false
	if dmg > 0:
		_apply_drain(target, dmg)
		_apply_life_steal(attacker, dmg)
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

func _weighted_target_pick(targets: Array) -> BattleUnit:
	if targets.size() <= 1:
		return targets[0] as BattleUnit
	var weights: Array = []
	var total: float = 0.0
	for t in targets:
		var unit := t as BattleUnit
		var w: float = 10.0
		var sd := _find_skill(unit, 30012)
		if not sd.is_empty():
			w += float(int(sd.get("p1", 0)))
		weights.append(w)
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if roll <= acc:
			return targets[i] as BattleUnit
	return targets[targets.size() - 1] as BattleUnit

# 迅捷（30008）：返回单位在排序时的有效出手速度（基础 + p1）
func _effective_spd(unit: BattleUnit) -> int:
	if unit == null:
		return 0
	var bonus: int = 0
	var sd := _find_skill(unit, 30008)
	if not sd.is_empty():
		bonus = int(sd.get("p1", 0))
	return unit.spd + bonus

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
	_spawn_skill_label(attacker, _skill_name(30001) + "!")
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
	if target.stunned:
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
	_spawn_skill_label(target, _skill_name(30002) + "!")
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

# 追击（skill_id=30005）：普攻击杀目标后，对随机存活敌人造成 p1% 伤害；继续击杀则循环触发
func _try_pursue_strike(attacker: BattleUnit, sf: SpriteFrames, has_atk_anim: bool, off_x: float) -> void:
	if attacker == null or attacker.is_dead:
		return
	var sd := _find_skill(attacker, 30005)
	if sd.is_empty():
		return
	var mult: float = float(int(sd.get("p1", 0))) / 100.0
	if mult <= 0.0:
		return
	var chase_has_sight := not _find_skill(attacker, 30010).is_empty()
	while not attacker.is_dead:
		var pool: Array = []
		for u in _battle_units:
			var e := u as BattleUnit
			if e == null or e.is_dead:
				continue
			if e.is_enemy == attacker.is_enemy:
				continue
			if not is_instance_valid(e.root):
				continue
			if e.stealth_rounds > 0 and not chase_has_sight:
				continue
			pool.append(e)
		if pool.is_empty():
			return
		var next_target := pool[randi() % pool.size()] as BattleUnit
		_spawn_skill_label(attacker, _skill_name(30005) + "!")
		# 冲到新目标前
		var dest: Vector2 = next_target.root.position + Vector2(off_x, 0)
		var tw_m := create_tween()
		tw_m.tween_property(attacker.root, "position", dest, MOVE_IN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw_m.finished
		if attacker.is_dead or not is_instance_valid(attacker.root):
			return
		# 播攻击动画 + 应用追击伤害
		if has_atk_anim and is_instance_valid(attacker.sprite) and sf and sf.has_animation("attack"):
			attacker.sprite.play("attack")
		await get_tree().create_timer(0.4).timeout
		if next_target.is_dead:
			# 目标在等待期间已被其他效果击杀，重新选一个继续追
			pass
		else:
			_apply_damage(attacker, next_target, mult)
		if has_atk_anim and is_instance_valid(attacker.sprite):
			if attacker.sprite.animation == "attack" and attacker.sprite.is_playing():
				await attacker.sprite.animation_finished
			if is_instance_valid(attacker.sprite):
				var back := "alert" if sf and sf.has_animation("alert") else "idle"
				if sf and sf.has_animation(back):
					attacker.sprite.play(back)
		# 没击杀，结束追击
		if not next_target.is_dead:
			return
		# 继续下一轮（while 循环重新挑选目标）

# 守护（skill_id=30003）：队友被普攻命中前，有 p1% 概率替队友分担 p2% 伤害
# 返回 {"protector": BattleUnit, "share": float(0~1)}；不触发返回 {}
func _try_protect_guard(target: BattleUnit, attacker: BattleUnit) -> Dictionary:
	if target == null or target.is_dead:
		return {}
	var candidates: Array = []
	for u in _battle_units:
		var ally := u as BattleUnit
		if ally == null or ally.is_dead:
			continue
		if ally == target:
			continue
		if ally.is_enemy != target.is_enemy:
			continue
		if not is_instance_valid(ally.root):
			continue
		var sd := _find_skill(ally, 30003)
		if sd.is_empty():
			continue
		candidates.append({"ally": ally, "sd": sd})
	if candidates.is_empty():
		return {}
	# 多人持有时随机一位尝试触发
	var pick: Dictionary = candidates[randi() % candidates.size()]
	var sd: Dictionary = pick["sd"]
	var prob: int = int(sd.get("p1", 0))
	if prob <= 0:
		return {}
	if (randi() % 100) >= prob:
		return {}
	var share: float = float(int(sd.get("p2", 0))) / 100.0
	if share <= 0.0:
		return {}
	return {"protector": pick["ally"], "share": share}

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
	_spawn_skill_label(attacker, _skill_name(40001) + "!")
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
	_spawn_skill_label(attacker, _skill_name(40002) + "!")
	return true

func _skill_name(sid: int) -> String:
	var sd := _get_skill_data(sid, 1)
	return String(sd.get("name", ""))

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
		lbl.text = "暴击 " + str(dmg)
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
		await _resolve_end_of_round()
	# 清理上一回合的灵魂汲取标记
	_clear_drain_marks()
	# 隐身（30009）：第一回合开战前初始化，其后每回合开始衰减一回合
	if _round_number == 0:
		_init_stealth_states()
	else:
		_tick_stealth_states()
	var alive: Array = []
	for u in _battle_units:
		var unit := u as BattleUnit
		if not unit.is_dead:
			alive.append(unit)
	# 按出手速度从高到低排序
	alive.sort_custom(func(a, b): return _effective_spd(a) > _effective_spd(b))
	_round_queue = alive
	_round_number += 1
	if is_instance_valid(_round_label):
		_round_label.text = "第 %d 回合" % _round_number
	# 回合切换 banner：放大淡出，期间整场停顿
	await _show_round_banner(_round_number)
	# 奇数回合（1,3,5...）随机一只怪物嘲讽
	if _round_number % 2 == 1 and not _taunt_texts.is_empty():
		_show_enemy_taunt()
	# 回合开始结算：自愈、灵魂汲取等
	await _resolve_start_of_round()

# 回合切换 banner：屏幕中央显示"第 N 回合"放大淡出，约 1.0s
func _show_round_banner(round_no: int) -> void:
	var vp := get_viewport_rect().size
	var lbl := Label.new()
	lbl.text = "第 %d 回合" % round_no
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(520, 120)
	lbl.position = Vector2((vp.x - 520) * 0.5, (vp.y - 120) * 0.5 - 40)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 200
	lbl.pivot_offset = Vector2(260, 60)
	var ls := LabelSettings.new()
	ls.font          = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	ls.font_size     = 72
	ls.font_color    = Color(1.0, 0.92, 0.5)
	ls.outline_size  = 8
	ls.outline_color = Color(0.1, 0.04, 0, 1.0)
	ls.shadow_size   = 6
	ls.shadow_color  = Color(0, 0, 0, 0.7)
	lbl.label_settings = ls
	lbl.scale = Vector2(0.4, 0.4)
	lbl.modulate = Color(1, 1, 1, 0)
	add_child(lbl)
	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(lbl, "modulate:a", 1.0, 0.2)
	await tw_in.finished
	await get_tree().create_timer(0.45).timeout
	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_out.tween_property(lbl, "modulate:a", 0.0, 0.25)
	await tw_out.finished
	lbl.queue_free()

# 隐身（30009）：开战前初始化各单位的隐身回合数与攻击伤害倍率
func _init_stealth_states() -> void:
	for u in _battle_units:
		var unit := u as BattleUnit
		if unit == null:
			continue
		var sd := _find_skill(unit, 30009)
		if sd.is_empty():
			continue
		var rounds: int = int(sd.get("p1", 0))
		var mult_pct: int = int(sd.get("p2", 0))
		if rounds <= 0 or mult_pct <= 0:
			continue
		unit.stealth_rounds = rounds
		unit.stealth_mult   = float(mult_pct) / 100.0
		# 若敌方拥有真视（30010），隐身者保留伤害加成但不再半透明（被看穿）
		if is_instance_valid(unit.sprite) and not _enemy_has_true_sight(unit):
			unit.sprite.modulate = Color(1, 1, 1, 0.35)

# 真视（30010）：检查 unit 对面阵营是否有人持有 30010 技能
func _enemy_has_true_sight(unit: BattleUnit) -> bool:
	for u in _battle_units:
		var other := u as BattleUnit
		if other == null or other.is_dead:
			continue
		if other.is_enemy == unit.is_enemy:
			continue
		if not _find_skill(other, 30010).is_empty():
			return true
	return false

# 每回合开始衰减一次；归零则恢复正常透明度
func _tick_stealth_states() -> void:
	for u in _battle_units:
		var unit := u as BattleUnit
		if unit == null or unit.is_dead:
			continue
		if unit.stealth_rounds <= 0:
			continue
		unit.stealth_rounds -= 1
		if unit.stealth_rounds <= 0:
			if is_instance_valid(unit.sprite):
				unit.sprite.modulate = Color(1, 1, 1, 1)

# 回合末统一结算：复苏（40003）等回合末效果
func _resolve_end_of_round() -> void:
	for u in _battle_units:
		var caster := u as BattleUnit
		if caster == null or caster.is_dead:
			continue
		if _try_revive_heal(caster):
			await get_tree().create_timer(0.45).timeout

# 复苏（skill_id=40003）：每回合末，为同阵营 HP 百分比最低的存活单位回复 p1 点生命
func _try_revive_heal(caster: BattleUnit) -> bool:
	var sd := _find_skill(caster, 40003)
	if sd.is_empty():
		return false
	var heal: int = int(sd.get("p1", 0))
	if heal <= 0:
		return false
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
		return false
	var new_hp: int = min(target.max_hp, target.cur_hp + heal)
	var actual: int = new_hp - target.cur_hp
	if actual <= 0:
		return false
	target.cur_hp = new_hp
	if is_instance_valid(target.status_bar):
		target.status_bar.update_hp(target.cur_hp)
	_spawn_skill_label(caster, _skill_name(40003) + "!")
	_spawn_heal_label(target, actual)
	return true

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
		_relayout_status_labels(unit)

func _resolve_start_of_round() -> void:
	for u in _battle_units:
		var caster := u as BattleUnit
		if caster == null or caster.is_dead:
			continue
		if not _find_skill(caster, 30012).is_empty():
			_spawn_skill_label(caster, _skill_name(30012) + "!")
		if _try_soul_drain_mark(caster):
			await get_tree().create_timer(0.4).timeout
		if _try_self_recovery(caster):
			await get_tree().create_timer(0.45).timeout

# 自愈（skill_id=30011）：每回合开始回复自身 p1% 最大血量
func _try_self_recovery(unit: BattleUnit) -> bool:
	if unit == null or unit.is_dead:
		return false
	var sd := _find_skill(unit, 30011)
	if sd.is_empty():
		return false
	var pct: int = int(sd.get("p1", 0))
	if pct <= 0:
		return false
	if unit.cur_hp >= unit.max_hp:
		return false
	var heal: int = max(1, int(round(float(unit.max_hp) * float(pct) / 100.0)))
	var new_hp: int = min(unit.max_hp, unit.cur_hp + heal)
	var actual: int = new_hp - unit.cur_hp
	if actual <= 0:
		return false
	unit.cur_hp = new_hp
	if is_instance_valid(unit.status_bar):
		unit.status_bar.update_hp(unit.cur_hp)
	_spawn_skill_label(unit, _skill_name(30011) + "!")
	_spawn_heal_label(unit, actual)
	return true

# 回合开始：从对方阵营存活单位中随机挑一个标记为汲取目标
func _try_soul_drain_mark(caster: BattleUnit) -> bool:
	var sd := _find_skill(caster, 40004)
	if sd.is_empty():
		return false
	var ratio: float = float(int(sd.get("p1", 0))) / 100.0
	if ratio <= 0.0:
		return false
	var caster_has_sight := not _find_skill(caster, 30010).is_empty()
	var enemies: Array = []
	for u in _battle_units:
		var e := u as BattleUnit
		if e == null or e.is_dead:
			continue
		if e.is_enemy != caster.is_enemy:
			if e.stealth_rounds > 0 and not caster_has_sight:
				continue
			enemies.append(e)
	if enemies.is_empty():
		return false
	var target: BattleUnit = enemies[randi() % enemies.size()]
	target.drain_sources.append({"caster": caster, "ratio": ratio})
	if not is_instance_valid(target.drain_label):
		_attach_drain_marker(target)
	_spawn_skill_label(caster, _skill_name(40004) + "!")
	return true

func _attach_drain_marker(target: BattleUnit) -> void:
	if not is_instance_valid(target.root):
		return
	var lbl := Label.new()
	lbl.text = "汲取"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(60, 32)
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
	_relayout_status_labels(target)

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

# 吸血（skill_id=30007）：普攻造成伤害时，攻击者回复伤害值 p1% 血量
func _apply_life_steal(attacker: BattleUnit, dmg: int) -> void:
	if attacker == null or attacker.is_dead or dmg <= 0:
		return
	var sd := _find_skill(attacker, 30007)
	if sd.is_empty():
		return
	var ratio: float = float(int(sd.get("p1", 0))) / 100.0
	if ratio <= 0.0:
		return
	var heal: int = int(round(float(dmg) * ratio))
	if heal <= 0:
		return
	if attacker.cur_hp >= attacker.max_hp:
		return
	var new_hp: int = min(attacker.max_hp, attacker.cur_hp + heal)
	var actual: int = new_hp - attacker.cur_hp
	if actual <= 0:
		return
	attacker.cur_hp = new_hp
	if is_instance_valid(attacker.status_bar):
		attacker.status_bar.update_hp(attacker.cur_hp)
	_spawn_heal_label(attacker, actual)


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
	_spawn_skill_label(attacker, _skill_name(40005) + "!")
	_attach_stun_marker(target)

func _clear_stun(target: BattleUnit) -> void:
	if target == null:
		return
	target.stunned = false
	if is_instance_valid(target.stun_label):
		target.stun_label.queue_free()
	target.stun_label = null
	_relayout_status_labels(target)

func _attach_stun_marker(target: BattleUnit) -> void:
	if not is_instance_valid(target.root):
		return
	if is_instance_valid(target.stun_label):
		target.stun_label.queue_free()
	var lbl := Label.new()
	lbl.text = "晕眩"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(60, 32)
	lbl.position = Vector2(0, -95)
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
	_relayout_status_labels(target)


# 把当前激活的异常状态标签按 1 个居中 / 2 个分左右的方式排好
func _relayout_status_labels(target: BattleUnit) -> void:
	if target == null:
		return
	var labels: Array = []
	if is_instance_valid(target.drain_label):
		labels.append(target.drain_label)
	if is_instance_valid(target.stun_label):
		labels.append(target.stun_label)
	var y: float = -95.0
	var gap: float = 4.0
	if labels.size() == 1:
		var lbl: Label = labels[0]
		lbl.position = Vector2(-lbl.size.x * 0.5, y)
	elif labels.size() >= 2:
		var left: Label = labels[0]
		var right: Label = labels[1]
		var total_w: float = left.size.x + gap + right.size.x
		left.position  = Vector2(-total_w * 0.5, y)
		right.position = Vector2(-total_w * 0.5 + left.size.x + gap, y)


# 结算面板经验条增长动画
func _animate_exp_bar(fill: Panel, inner_w: float, fill_h: float, row: Dictionary, fill_style: StyleBoxFlat, text_lbl: Label = null, _final_max: int = 0) -> void:
	fill.set_meta("inner_w", inner_w)
	fill.set_meta("fill_h",  fill_h)
	var from_lv: int = int(row.get("from_level", 1))
	var to_lv: int = int(row.get("to_level", 1))
	var from_exp: int = int(row.get("from_exp", 0))
	var to_exp: int = int(row.get("to_exp", 0))
	var from_max: int = int(row.get("from_max_exp", 0))
	var to_max: int = int(row.get("to_max_exp", 0))
	var seg_dur: float = 1.2
	var tw := create_tween()
	# 入场延迟，让用户看到起始进度
	tw.tween_interval(0.35)
	if to_lv == from_lv:
		var max_v: int = to_max if to_max > 0 else 1
		tw.tween_method(_set_bar_progress.bind(fill, text_lbl, max_v), float(from_exp), float(to_exp), seg_dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if to_max <= 0:
			tw.tween_callback(func() -> void:
				fill_style.bg_color = Color(1.0, 0.85, 0.35)
				if is_instance_valid(text_lbl):
					text_lbl.text = "MAX")
		return
	# 跨级动画：先涨满当前级，闪光，回到 0，再涨下一级
	if from_max > 0:
		var s_ratio: float = float(from_exp) / float(from_max)
		tw.tween_method(_set_bar_progress.bind(fill, text_lbl, from_max), float(from_exp), float(from_max), seg_dur * (1.0 - s_ratio + 0.2)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_flash_level_up.bind(fill_style, fill))
	# 末段
	if to_max > 0:
		var e_ratio: float = float(to_exp) / float(to_max)
		tw.tween_method(_set_bar_progress.bind(fill, text_lbl, to_max), 0.0, float(to_exp), seg_dur * (e_ratio + 0.2)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_callback(func() -> void:
			fill_style.bg_color = Color(1.0, 0.85, 0.35)
			if is_instance_valid(text_lbl):
				text_lbl.text = "MAX")

func _set_bar_progress(exp_val: float, fill: Panel, text_lbl: Label, max_v: int) -> void:
	if not is_instance_valid(fill):
		return
	var inner_w: float = float(fill.get_meta("inner_w", 0.0))
	var fill_h:  float = float(fill.get_meta("fill_h",  fill.size.y))
	var ratio: float = 0.0
	if max_v > 0:
		ratio = clamp(exp_val / float(max_v), 0.0, 1.0)
	fill.size = Vector2(max(0.0, inner_w * ratio), fill_h)
	if is_instance_valid(text_lbl):
		text_lbl.text = "%d / %d" % [int(round(exp_val)), max_v]

func _flash_level_up(fill_style: StyleBoxFlat, fill: Panel) -> void:
	if not is_instance_valid(fill):
		return
	var c0: Color = fill_style.bg_color
	fill_style.bg_color = Color(1.0, 1.0, 0.7)
	var flash := create_tween()
	flash.tween_method(func(t: float) -> void:
		fill_style.bg_color = Color(1.0, 1.0, 0.7).lerp(c0, t),
		0.0, 1.0, 0.25)


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
	var clear_info: Dictionary = {}
	if victory:
		clear_info = _record_level_cleared()
	var vp := get_viewport_rect().size
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	var title := "胜利！" if victory else "战败..."
	var title_color := Color(1.0, 0.9, 0.2) if victory else Color(1.0, 0.3, 0.3)

	var exp_rows: Array = clear_info.get("rows", []) if victory else []
	var drop_item: Dictionary = clear_info.get("drop", {}) if victory else {}
	var avatar_size := 72.0
	var cell_w := 100.0
	var cell_gap := 28.0
	var rows_area_h: float = 0.0
	if exp_rows.size() > 0:
		rows_area_h = 16.0 + avatar_size + 6.0 + 22.0 + 4.0 + 18.0 + 4.0 + 22.0 + 16.0
	var tip_area_h: float = 60.0 if not victory else 0.0
	var drop_area_h: float = 85.0 if not drop_item.is_empty() else 0.0
	var min_panel_w := 460.0
	var gap_count: int = max(0, exp_rows.size() - 1)
	var needed_w: float = float(exp_rows.size()) * cell_w + float(gap_count) * cell_gap + 56.0
	var panel_w: float = max(min_panel_w, needed_w)
	var panel_h: float = 200.0 + rows_area_h + drop_area_h + tip_area_h
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.30, 0.95)
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

	# 角色头像 + 等级/经验（仅胜利时，横向排列）
	if exp_rows.size() > 0:
		var gap_count2: int = max(0, exp_rows.size() - 1)
		var total_w: float = float(exp_rows.size()) * cell_w + float(gap_count2) * cell_gap
		var start_x: float = panel.position.x + (panel_w - total_w) * 0.5
		var top_y: float = panel.position.y + 96.0
		var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		for i in exp_rows.size():
			var row: Dictionary = exp_rows[i]
			var rid: String = String(row.get("role_id", ""))
			var role_idx: int = int(rid) - 10000
			var cx: float = start_x + float(i) * (cell_w + cell_gap)

			# 头像
			var avatar_path := "res://asserts/image/role/role%d_avatar.png" % role_idx
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(avatar_size, avatar_size)
			tr.size = Vector2(avatar_size, avatar_size)
			tr.position = Vector2(cx + (cell_w - avatar_size) * 0.5, top_y)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if ResourceLoader.exists(avatar_path):
				tr.texture = load(avatar_path)
			ui.add_child(tr)
			tr.size = Vector2(avatar_size, avatar_size)

			var to_lv: int = int(row.get("to_level", 1))
			var from_lv: int = int(row.get("from_level", 1))
			var leveled_up: bool = to_lv > from_lv

			# 等级
			var lv_lbl := Label.new()
			lv_lbl.text = ("Lv.%d -> Lv.%d" % [from_lv, to_lv]) if leveled_up else ("Lv.%d" % to_lv)
			lv_lbl.size = Vector2(cell_w, 22.0)
			lv_lbl.position = Vector2(cx, top_y + avatar_size + 6.0)
			lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			var ls1 := LabelSettings.new()
			ls1.font = font
			ls1.font_size = 18
			ls1.font_color = Color(1.0, 0.95, 0.55) if leveled_up else Color(0.88, 0.93, 1.0)
			ls1.outline_size = 3
			ls1.outline_color = Color(0, 0, 0, 1.0)
			lv_lbl.label_settings = ls1
			ui.add_child(lv_lbl)

			# 经验条
			var bar_h := 18.0
			var bar_w: float = cell_w - 8.0
			var bar_x: float = cx + (cell_w - bar_w) * 0.5
			var bar_y: float = top_y + avatar_size + 6.0 + 22.0 + 4.0
			var max_exp: int = int(row.get("to_max_exp", 0))
			var to_exp: int = int(row.get("to_exp", 0))
			var from_exp: int = int(row.get("from_exp", 0))
			var from_max_exp: int = int(row.get("from_max_exp", 0))
			var start_ratio: float = 0.0
			if from_max_exp > 0:
				start_ratio = clamp(float(from_exp) / float(from_max_exp), 0.0, 1.0)
			else:
				start_ratio = 1.0
			var bar_bg_style := StyleBoxFlat.new()
			bar_bg_style.bg_color = Color(0.10, 0.12, 0.18, 0.95)
			bar_bg_style.set_corner_radius_all(3)
			bar_bg_style.border_width_top    = 1
			bar_bg_style.border_width_bottom = 1
			bar_bg_style.border_width_left   = 1
			bar_bg_style.border_width_right  = 1
			bar_bg_style.border_color = Color(0, 0, 0, 0.7)
			var bar_bg := Panel.new()
			bar_bg.size = Vector2(bar_w, bar_h)
			bar_bg.position = Vector2(bar_x, bar_y)
			bar_bg.add_theme_stylebox_override("panel", bar_bg_style)
			bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.add_child(bar_bg)
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = Color(0.45, 0.85, 0.55) if max_exp > 0 else Color(1.0, 0.85, 0.35)
			fill_style.set_corner_radius_all(3)
			var fill := Panel.new()
			var inner_w: float = bar_w - 2.0
			var min_fill: float = 0.0  # 允许 0 宽，避免起始空段也有一段
			fill.size = Vector2(max(min_fill, inner_w * start_ratio), bar_h - 2.0)
			fill.position = Vector2(bar_x + 1.0, bar_y + 1.0)
			fill.add_theme_stylebox_override("panel", fill_style)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.add_child(fill)
			# 经验条上叠一层文字 "cur/max" 或 "MAX"
			var bar_text_lbl := Label.new()
			bar_text_lbl.size = Vector2(bar_w, bar_h)
			bar_text_lbl.position = Vector2(bar_x, bar_y)
			bar_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bar_text_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			bar_text_lbl.text = ("%d / %d" % [from_exp, from_max_exp]) if from_max_exp > 0 else "MAX"
			bar_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bls := LabelSettings.new()
			bls.font = font
			bls.font_size = 13
			bls.font_color = Color(1, 1, 1, 1)
			bls.outline_size = 3
			bls.outline_color = Color(0, 0, 0, 0.9)
			bar_text_lbl.label_settings = bls
			ui.add_child(bar_text_lbl)
			# 动画：起始 ratio → 末尾 ratio，跨级时分段
			_animate_exp_bar(fill, inner_w, bar_h - 2.0, row, fill_style, bar_text_lbl, max_exp)

			# 经验
			var exp_lbl := Label.new()
			exp_lbl.text = "+%d EXP" % int(row.get("exp_gain", 0))
			exp_lbl.size = Vector2(cell_w, 22.0)
			exp_lbl.position = Vector2(cx, bar_y + bar_h + 4.0)
			exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			exp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			var ls2 := LabelSettings.new()
			ls2.font = font
			ls2.font_size = 14
			ls2.font_color = Color(0.85, 0.95, 0.75)
			ls2.outline_size = 3
			ls2.outline_color = Color(0, 0, 0, 1.0)
			exp_lbl.label_settings = ls2
			ui.add_child(exp_lbl)

	# 装备掉落显示（标签 + 图标 + 装备名）
	if not drop_item.is_empty():
		var drop_y: float = panel.position.y + 96.0 + rows_area_h
		var icon_size := 52.0
		var drop_lbl := Label.new()
		drop_lbl.text = "获得装备:"
		var dls := LabelSettings.new()
		dls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		dls.font_size = 18
		dls.font_color = Color(0.9, 0.92, 0.85)
		dls.outline_size = 2
		dls.outline_color = Color(0, 0, 0, 0.8)
		drop_lbl.label_settings = dls
		drop_lbl.position = Vector2(panel.position.x + panel_w * 0.5 - 70, drop_y + 25)
		ui.add_child(drop_lbl)
		var drop_icon_path: String = String(drop_item.get("icon", ""))
		if not drop_icon_path.is_empty() and ResourceLoader.exists(drop_icon_path):
			var icon_pos := Vector2(panel.position.x + panel_w * 0.5 + 40, drop_y + 8)
			var drop_icon := TextureRect.new()
			drop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			drop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			drop_icon.custom_minimum_size = Vector2(icon_size, icon_size)
			drop_icon.size = Vector2(icon_size, icon_size)
			drop_icon.position = icon_pos
			drop_icon.texture = load(drop_icon_path)
			drop_icon.mouse_filter = Control.MOUSE_FILTER_STOP
			drop_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			drop_icon.gui_input.connect(_on_drop_item_click.bind(drop_item, ui))
			ui.add_child(drop_icon)
			var equip_name: String = String(drop_item.get("name", ""))
			if not equip_name.is_empty():
				var name_lbl := Label.new()
				name_lbl.text = equip_name
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.size = Vector2(icon_size + 40, 22.0)
				name_lbl.position = Vector2(icon_pos.x - 20, icon_pos.y + icon_size + 4)
				var nls := LabelSettings.new()
				nls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
				nls.font_size = 14
				nls.font_color = Color(1.0, 0.85, 0.4)
				nls.outline_size = 2
				nls.outline_color = Color(0, 0, 0, 0.9)
				name_lbl.label_settings = nls
				ui.add_child(name_lbl)

	if not victory:
		var tip_lbl := Label.new()
		tip_lbl.text = "提升星级、穿戴装备、学习技能、更改阵容可增强战力"
		tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_lbl.size = Vector2(panel_w - 40, 50.0)
		tip_lbl.position = Vector2(panel.position.x + 20, panel.position.y + 96.0)
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tip_ls := LabelSettings.new()
		tip_ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		tip_ls.font_size = 18
		tip_ls.font_color = Color(0.9, 0.85, 0.6)
		tip_ls.outline_size = 2
		tip_ls.outline_color = Color(0, 0, 0, 0.8)
		tip_lbl.label_settings = tip_ls
		ui.add_child(tip_lbl)

	var btn_y: float = panel.position.y + 110.0 + rows_area_h + drop_area_h + tip_area_h
	var btn_w := 120.0
	var btn_h := 52.0
	var gap := 30.0
	var back_btn := _make_button("返回", Vector2(panel.position.x + (panel_w - btn_w) * 0.5, btn_y), Vector2(btn_w, btn_h))
	ui.add_child(back_btn.panel)
	ui.add_child(back_btn.label)
	back_btn.label.gui_input.connect(_on_exit_input)

	if victory:
		var next_id := _next_level_id_str()
		if not next_id.is_empty():
			var x0 := panel.position.x + (panel_w - (btn_w * 2 + gap)) * 0.5
			back_btn.panel.position = Vector2(x0, btn_y)
			back_btn.label.position = Vector2(x0, btn_y)
			var next_btn := _make_button("下一关", Vector2(x0 + btn_w + gap, btn_y), Vector2(btn_w, btn_h))
			ui.add_child(next_btn.panel)
			ui.add_child(next_btn.label)
			next_btn.label.gui_input.connect(_on_next_level_input.bind(next_id))
	else:
		var x0 := panel.position.x + (panel_w - (btn_w * 2 + gap)) * 0.5
		back_btn.panel.position = Vector2(x0, btn_y)
		back_btn.label.position = Vector2(x0, btn_y)
		var retry_btn := _make_button("重新挑战", Vector2(x0 + btn_w + gap, btn_y), Vector2(btn_w, btn_h))
		ui.add_child(retry_btn.panel)
		ui.add_child(retry_btn.label)
		retry_btn.label.gui_input.connect(_on_retry_input)

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
	if _formation_team_ids.is_empty():
		_formation_team_ids = _get_team_ids()
	var team_ids := _formation_team_ids

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

		var pos_lbl := Label.new()
		pos_lbl.text = str(i + 1)
		pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pos_lbl.size = Vector2(40, 24)
		pos_lbl.position = Vector2(-20, fh * rd.idle_scale * 0.4)
		var pos_ls := LabelSettings.new()
		pos_ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
		pos_ls.font_size = 18
		pos_ls.font_color = Color(1.0, 0.9, 0.5, 0.9)
		pos_ls.outline_size = 2
		pos_ls.outline_color = Color(0, 0, 0, 0.8)
		pos_lbl.label_settings = pos_ls
		root.add_child(pos_lbl)

		var bonus_table := _load_formation_bonus_table()
		var fid := int(formation["id"])
		if bonus_table.has(fid) and bonus_table[fid].has(i + 1):
			var bonus_text := _get_bonus_text(bonus_table[fid][i + 1])
			if not bonus_text.is_empty():
				var bonus_lbl := Label.new()
				bonus_lbl.text = bonus_text
				bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bonus_lbl.size = Vector2(160, 22)
				bonus_lbl.position = Vector2(-80, -fh * rd.idle_scale * 0.5 - 20)
				bonus_lbl.z_index = 50
				var bonus_ls := LabelSettings.new()
				bonus_ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
				bonus_ls.font_size = 14
				bonus_ls.font_color = Color(0.6, 1.0, 0.6, 0.95)
				bonus_ls.outline_size = 2
				bonus_ls.outline_color = Color(0, 0, 0, 0.9)
				bonus_lbl.label_settings = bonus_ls
				root.add_child(bonus_lbl)

func _build_formation_overlay(vp: Vector2) -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var bar_w := 500.0
	var bar_h := 58.0
	var bar_x := (vp.x - bar_w) * 0.5
	var bar_y := 16.0

	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.12, 0.20, 0.38, 0.90)
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

	var tips_lbl := Label.new()
	tips_lbl.text = "提示：鼠标拖动角色可以交换位置"
	tips_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips_lbl.size = Vector2(bar_w, 36)
	tips_lbl.position = Vector2(bar_x, bar_y + bar_h + 8)
	tips_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tips_ls := LabelSettings.new()
	tips_ls.font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	tips_ls.font_size = 20
	tips_ls.font_color = Color(1.0, 0.95, 0.6, 1.0)
	tips_ls.outline_size = 3
	tips_ls.outline_color = Color(0, 0, 0, 1.0)
	tips_lbl.label_settings = tips_ls
	ui.add_child(tips_lbl)

	var next_btn := _make_arrow_button(">", Vector2(bar_x + bar_w - 54, bar_y + 5), Vector2(44, 48))
	ui.add_child(next_btn.panel)
	ui.add_child(next_btn.label)
	next_btn.label.gui_input.connect(_on_formation_next)

	var confirm_btn := _make_button("确认", Vector2(vp.x * 0.5 - 135, vp.y - 74), Vector2(120, 52))
	ui.add_child(confirm_btn.panel)
	ui.add_child(confirm_btn.label)
	confirm_btn.label.gui_input.connect(_on_formation_confirm)

	var cancel_btn := _make_button("取消", Vector2(vp.x * 0.5 + 15, vp.y - 74), Vector2(120, 52))
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
		_save_team_order()
		_go_back_main()

func _on_formation_cancel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_go_back_main()

func _input(event: InputEvent) -> void:
	if _scene_mode != "formation":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_formation_drag_start(event.position)
		else:
			_formation_drag_end(event.position)
	elif event is InputEventMouseMotion and _drag_index >= 0:
		_formation_role_nodes[_drag_index].position = event.position - _drag_offset

func _formation_drag_start(pos: Vector2) -> void:
	for i in _formation_role_nodes.size():
		var node: Node2D = _formation_role_nodes[i]
		if not is_instance_valid(node):
			continue
		if node.position.distance_to(pos) < 60.0:
			_drag_index = i
			_drag_offset = pos - node.position
			_drag_original_pos = node.position
			node.z_index = 100
			return

func _formation_drag_end(pos: Vector2) -> void:
	if _drag_index < 0:
		return
	var dragged_node: Node2D = _formation_role_nodes[_drag_index]
	var swap_idx: int = -1
	for i in _formation_role_nodes.size():
		if i == _drag_index:
			continue
		var node: Node2D = _formation_role_nodes[i]
		if not is_instance_valid(node):
			continue
		if node.position.distance_to(pos) < 60.0:
			swap_idx = i
			break
	if swap_idx >= 0:
		var other_node: Node2D = _formation_role_nodes[swap_idx]
		var other_pos: Vector2 = other_node.position
		other_node.position = _drag_original_pos
		dragged_node.position = other_pos
		_formation_role_nodes[_drag_index] = other_node
		_formation_role_nodes[swap_idx] = dragged_node
		var tmp: String = _formation_team_ids[_drag_index]
		_formation_team_ids[_drag_index] = _formation_team_ids[swap_idx]
		_formation_team_ids[swap_idx] = tmp
		_refresh_formation_pos_labels()
	else:
		dragged_node.position = _drag_original_pos
	dragged_node.z_index = 0
	_drag_index = -1

func _refresh_formation_pos_labels() -> void:
	var bonus_table := _load_formation_bonus_table()
	var fid := int(_formations[_current_formation_idx]["id"]) if _formations.size() > 0 else 0
	for i in _formation_role_nodes.size():
		var node: Node2D = _formation_role_nodes[i]
		if not is_instance_valid(node):
			continue
		var label_idx: int = 0
		for child in node.get_children():
			if child is Label:
				if label_idx == 0:
					child.text = str(i + 1)
				elif label_idx == 1:
					if bonus_table.has(fid) and bonus_table[fid].has(i + 1):
						child.text = _get_bonus_text(bonus_table[fid][i + 1])
					else:
						child.text = ""
				label_idx += 1

func _save_team_order() -> void:
	var save_path := "user://savegame.json"
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary:
				data = parsed
	data["team_ids"] = _formation_team_ids
	var wf := FileAccess.open(save_path, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(data))
		wf.close()

func _go_back_main() -> void:
	var main := load(MAIN_SCENE_PATH) as PackedScene
	SceneTransition.change_to(main)

func _record_level_cleared() -> Dictionary:
	var result: Dictionary = {"rows": []}
	var save_path := "user://savegame.json"
	var level_id_str: String = String(GlobalConfig.get_runtime("level_id"))
	if not level_id_str.is_valid_int():
		return result
	var cleared_id := int(level_id_str)
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary:
				data = parsed

	# 每次通关都累加经验
	if cleared_id > int(data.get("cleared_level", 0)):
		data["cleared_level"] = cleared_id
	result["rows"] = _grant_exp_to_team(data, cleared_id)

	# 胜利必定掉落一件装备（每种类型上限32件）
	var inv: Array = data.get("inventory", []) if data.get("inventory", null) is Array else []
	var drop := _generate_equipment_drop(data, inv)
	if not drop.is_empty():
		result["drop"] = drop
		inv.append(drop)
		data["inventory"] = inv

	var wf := FileAccess.open(save_path, FileAccess.WRITE)
	if wf == null:
		return result
	wf.store_string(JSON.stringify(data))
	wf.close()
	return result

func _grant_exp_to_team(data: Dictionary, cleared_id: int) -> Array:
	var rows: Array = []
	var levels_data := _load_levels_table()
	var lid_str := str(cleared_id)
	if not levels_data.has(lid_str):
		return rows
	var exp_gain: int = int(levels_data[lid_str].get("exp", 0))
	if exp_gain <= 0:
		return rows
	var team_ids := _get_team_ids()
	if team_ids.is_empty():
		return rows
	var level_up := _load_level_up_table()
	var roles_data := _load_roles_table()
	var roles_state: Dictionary = {}
	if data.has("roles") and data["roles"] is Dictionary:
		roles_state = data["roles"]
	for rid in team_ids:
		var st: Dictionary = roles_state.get(rid, {})
		var lv: int = int(st.get("level", 1))
		var from_lv: int = lv
		var from_exp: int = int(st.get("exp", 0))
		var cur_exp: int = from_exp + exp_gain
		var promoted := _apply_level_up(lv, cur_exp, level_up)
		st["level"] = promoted.level
		st["exp"] = promoted.exp
		if not st.has("star"):
			st["star"] = 1
		roles_state[rid] = st
		var role_name: String = ""
		if roles_data.has(rid):
			role_name = String((roles_data[rid] as Dictionary).get("name", rid))
		if role_name.is_empty():
			role_name = String(rid)
		var to_lv: int = int(promoted.level)
		var to_exp: int = int(promoted.exp)
		var to_max_exp: int = int(level_up.get(to_lv, 0))
		var from_max_exp: int = int(level_up.get(from_lv, 0))
		rows.append({
			"role_id":      rid,
			"name":         role_name,
			"from_level":   from_lv,
			"to_level":     to_lv,
			"from_exp":     from_exp,
			"to_exp":       to_exp,
			"from_max_exp": from_max_exp,
			"to_max_exp":   to_max_exp,
			"exp_gain":     exp_gain,
		})
	data["roles"] = roles_state
	return rows

const EQUIP_SLOT_LIMIT := 32

func _generate_equipment_drop(data: Dictionary, inv: Array) -> Dictionary:
	var equip_table := _load_equipment_table()
	if equip_table.is_empty():
		return {}
	var tower_lv: int = 1
	if data.has("levels") and data["levels"] is Dictionary:
		tower_lv = int((data["levels"] as Dictionary).get("tower", 1))
	var equip_level: int = tower_lv * 10
	var ids := equip_table.keys()
	# 过滤掉已满上限的类型
	var valid_ids: Array = []
	var slot_counts: Dictionary = {}
	for item in inv:
		var s: String = String(item.get("slot", ""))
		slot_counts[s] = int(slot_counts.get(s, 0)) + 1
	for eid in ids:
		var tpl: Dictionary = equip_table[eid]
		var slot: String = tpl["slot"]
		if int(slot_counts.get(slot, 0)) < EQUIP_SLOT_LIMIT:
			valid_ids.append(eid)
	if valid_ids.is_empty():
		return {}
	var eid: int = valid_ids[randi() % valid_ids.size()]
	var tpl: Dictionary = equip_table[eid]
	var scale: float = 1.0 + (equip_level - 10) * 0.10
	return {
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

func _load_equipment_table() -> Dictionary:
	var result := {}
	var file := FileAccess.open(EQUIPMENT_TABLE_PATH, FileAccess.READ)
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
		if parts.size() < 16:
			continue
		var eid := int((parts[0] as String).strip_edges())
		result[eid] = {
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
	return result

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

# 技能表：返回 {skill_id_int: {level_int: {desc, p1, p2, icon}}}
# 技能升级金币消耗统一从 skill_upgrade_cost.txt 读取，不再随技能配置
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
			"name":         String(entry.get("name", "")),
			"desc":         String(entry.get("desc", "")),
			"p1":           int(entry.get("param1", "0")),
			"p2":           int(entry.get("param2", "0")),
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

# 技能升级金币消耗表：{level_int: cost_int}（lv 1 = 0）
var _skill_cost_cache: Dictionary = {}
func _load_skill_upgrade_costs() -> Dictionary:
	if not _skill_cost_cache.is_empty():
		return _skill_cost_cache
	var result: Dictionary = {}
	var file := FileAccess.open(SKILL_UPGRADE_COST_PATH, FileAccess.READ)
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
		var cost_s: String = (parts[1] as String).strip_edges()
		if not lv_s.is_valid_int():
			continue
		result[int(lv_s)] = int(cost_s) if cost_s.is_valid_int() else 0
	_skill_cost_cache = result
	return result

# 升级到目标等级所需金币；目标等级不在表中时返回 0
func _get_skill_upgrade_cost(target_lv: int) -> int:
	var t := _load_skill_upgrade_costs()
	return int(t.get(target_lv, 0))

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
		var bonus_table := _load_formation_bonus_table()
		if bonus_table.has(formation_id) and bonus_table[formation_id].has(i + 1):
			attrs = _apply_formation_bonus(attrs, bonus_table[formation_id][i + 1])
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
		var enemy_fid := int(level["formation_id"])
		var bonus_table := _load_formation_bonus_table()
		if bonus_table.has(enemy_fid) and bonus_table[enemy_fid].has(i + 1):
			attrs = _apply_formation_bonus(attrs, bonus_table[enemy_fid][i + 1])
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
		unit.skills     = _parse_monster_skills(level.get("monster_skills", ""))
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
	var hp: int    = a.init_hp    + (lv - 1) * a.lv_hp    + star * a.star_hp
	var atk: int   = a.init_atk   + (lv - 1) * a.lv_atk   + star * a.star_atk
	var def: int   = a.init_def   + (lv - 1) * a.lv_def   + star * a.star_def
	var spd: int   = a.init_speed + (lv - 1) * a.lv_speed + star * a.star_speed
	var crit: int  = a.init_crit  + (lv - 1) * a.lv_crit  + star * a.star_crit
	var dodge: int = a.init_dodge + (lv - 1) * a.lv_dodge + star * a.star_dodge
	# 装备属性加成
	var save_data := _load_save_data()
	var role_equips: Dictionary = save_data.get("role_equips", {}) if save_data.get("role_equips", null) is Dictionary else {}
	var inventory: Array = save_data.get("inventory", []) if save_data.get("inventory", null) is Array else []
	var equips: Dictionary = role_equips.get(rid, {}) if role_equips.get(rid, null) is Dictionary else {}
	var suit_members := _load_suit_members_table()
	var suit_counts: Dictionary = {}
	for sk in equips.keys():
		var inv_idx: int = int(equips[sk])
		if inv_idx >= 0 and inv_idx < inventory.size():
			var item: Dictionary = inventory[inv_idx]
			atk   += int(item.get("atk", 0))
			def   += int(item.get("def", 0))
			hp    += int(item.get("hp", 0))
			spd   += int(item.get("speed", 0))
			crit  += int(item.get("crit", 0))
			dodge += int(item.get("dodge", 0))
			var eid: int = int(item.get("id", 0))
			if suit_members.has(eid):
				var sn: String = suit_members[eid]
				suit_counts[sn] = int(suit_counts.get(sn, 0)) + 1
	# 套装属性加成
	var suit_data := _load_suit_bonus_table()
	for sn in suit_counts.keys():
		var count: int = int(suit_counts[sn])
		if suit_data.has(sn):
			for bonus in suit_data[sn]:
				if int(bonus["require_count"]) <= count:
					atk   += int(bonus.get("atk", 0))
					def   += int(bonus.get("def", 0))
					hp    += int(bonus.get("hp", 0))
					spd   += int(bonus.get("speed", 0))
					crit  += int(bonus.get("crit", 0))
					dodge += int(bonus.get("dodge", 0))
	return {"hp": hp, "atk": atk, "def": def, "spd": spd, "crit": crit, "dodge": dodge}

func _load_save_data() -> Dictionary:
	var save_path := "user://savegame.json"
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}

func _load_suit_members_table() -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open("res://asserts/table/suit_members.txt", FileAccess.READ)
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
		if parts.size() < 3:
			continue
		var suit_name: String = (parts[1] as String).strip_edges()
		for eid_str in (parts[2] as String).strip_edges().split(","):
			var eid: int = int(eid_str.strip_edges())
			if eid > 0:
				result[eid] = suit_name
	return result

func _load_suit_bonus_table() -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open("res://asserts/table/suit.txt", FileAccess.READ)
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
		if parts.size() < 12:
			continue
		var suit_name: String = (parts[2] as String).strip_edges()
		if not result.has(suit_name):
			result[suit_name] = []
		result[suit_name].append({
			"require_count": int(parts[4]),
			"atk": int(parts[6]), "def": int(parts[7]), "hp": int(parts[8]),
			"speed": int(parts[9]), "crit": int(parts[10]), "dodge": int(parts[11]),
		})
	return result

func _apply_formation_bonus(attrs: Dictionary, bonus: Dictionary) -> Dictionary:
	return {
		"hp":    int(attrs.hp    * (1.0 + float(bonus.get("hp", 0)) / 100.0)),
		"atk":   int(attrs.atk   * (1.0 + float(bonus.get("atk", 0)) / 100.0)),
		"def":   int(attrs.def   * (1.0 + float(bonus.get("def", 0)) / 100.0)),
		"spd":   int(attrs.spd   * (1.0 + float(bonus.get("spd", 0)) / 100.0)),
		"crit":  int(attrs.crit  * (1.0 + float(bonus.get("crit", 0)) / 100.0)),
		"dodge": int(attrs.dodge * (1.0 + float(bonus.get("dodge", 0)) / 100.0)),
	}

var _formation_bonus_cache: Dictionary = {}
func _load_formation_bonus_table() -> Dictionary:
	if not _formation_bonus_cache.is_empty():
		return _formation_bonus_cache
	var result: Dictionary = {}
	var file := FileAccess.open(FORMATION_BONUS_PATH, FileAccess.READ)
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
		if parts.size() < 8:
			continue
		var fid_s: String = (parts[0] as String).strip_edges()
		var pos_s: String = (parts[1] as String).strip_edges()
		if not fid_s.is_valid_int() or not pos_s.is_valid_int():
			continue
		var fid := int(fid_s)
		var pos := int(pos_s)
		if not result.has(fid):
			result[fid] = {}
		result[fid][pos] = {
			"hp":    int((parts[2] as String).strip_edges()),
			"atk":   int((parts[3] as String).strip_edges()),
			"def":   int((parts[4] as String).strip_edges()),
			"spd":   int((parts[5] as String).strip_edges()),
			"crit":  int((parts[6] as String).strip_edges()),
			"dodge": int((parts[7] as String).strip_edges()),
		}
	_formation_bonus_cache = result
	return result

func _get_bonus_text(bonus: Dictionary) -> String:
	var parts: Array = []
	if int(bonus.get("hp", 0)) > 0:
		parts.append("血+%d%%" % int(bonus.hp))
	if int(bonus.get("atk", 0)) > 0:
		parts.append("攻+%d%%" % int(bonus.atk))
	if int(bonus.get("def", 0)) > 0:
		parts.append("防+%d%%" % int(bonus.def))
	if int(bonus.get("spd", 0)) > 0:
		parts.append("速+%d%%" % int(bonus.spd))
	if int(bonus.get("crit", 0)) > 0:
		parts.append("暴+%d%%" % int(bonus.crit))
	if int(bonus.get("dodge", 0)) > 0:
		parts.append("闪+%d%%" % int(bonus.dodge))
	return " ".join(parts)

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
			"name":            String(entry.get("name",           "")),
			"gender":          String(entry.get("gender",         "male")),
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
			"monster_skills": String(entry.get("monster_skills", "")),
		}
	return result

func _parse_monster_skills(skills_str: String) -> Array:
	var result: Array = []
	var s := skills_str.strip_edges()
	if s.is_empty():
		return result
	for piece in s.split(","):
		var p: String = (piece as String).strip_edges()
		if p.is_empty():
			continue
		var parts := p.split(":")
		if parts.size() < 2:
			continue
		var sid: int = int((parts[0] as String).strip_edges())
		var lv: int = int((parts[1] as String).strip_edges())
		if sid > 0 and lv > 0:
			result.append({"id": sid, "level": lv})
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
# 技能等级统一取全局 research_levels，角色身上只记录装备了哪些技能 id
func _get_role_skills(rid: String) -> Array:
	var star: int = 1
	var skills_raw: Array = []
	var research_levels: Dictionary = {}
	var save_path := "user://savegame.json"
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				if parsed.has("research_levels") and parsed["research_levels"] is Dictionary:
					for k in parsed["research_levels"]:
						research_levels[int(k)] = int(parsed["research_levels"][k])
				if parsed.has("roles") and parsed["roles"] is Dictionary:
					var rs: Dictionary = parsed["roles"]
					if rs.has(rid) and rs[rid] is Dictionary:
						var rd: Dictionary = rs[rid]
						star = int(rd.get("star", 1))
						if rd.has("skills") and rd["skills"] is Array:
							for s in rd["skills"]:
								if s is Dictionary and int(s.get("id", 0)) > 0:
									var sid: int = int(s.get("id", 0))
									var lv: int = int(research_levels.get(sid, 1))
									skills_raw.append({"id": sid, "level": lv})
	if skills_raw.is_empty():
		for s in DEFAULT_SKILLS:
			var sid: int = int(s.id)
			var lv: int = int(research_levels.get(sid, 1))
			skills_raw.append({"id": sid, "level": lv})
	var slots: int = star + 1
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

func _on_drop_item_click(event: InputEvent, item: Dictionary, parent_ui: CanvasLayer) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var vp := get_viewport_rect().size
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var popup_w := 280.0
	var popup_h := 300.0
	var container := Control.new()
	container.size = vp
	parent_ui.add_child(container)
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
	name_lbl.text = "%s" % String(item.get("name", ""))
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
	# 右上角红色关闭按钮
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

func _on_exit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main := load(MAIN_SCENE_PATH) as PackedScene
		SceneTransition.change_to(main)

func _on_retry_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var scene := load(BATTLE_SCENE_PATH) as PackedScene
		SceneTransition.change_to(scene)

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
	style.bg_color = Color(0.22, 0.18, 0.10, 0.92)
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
	style.bg_color = Color(0.20, 0.38, 0.68, 0.90)
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
# 战斗中怪物嘲讽
# ─────────────────────────────────────────────────────────────────────────────

func _load_taunt_texts() -> void:
	if not FileAccess.file_exists(MONSTER_TAUNTS_PATH):
		return
	var file := FileAccess.open(MONSTER_TAUNTS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var lines := text.split("\n", false)
	for i in range(1, lines.size()):
		var line: String = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		_taunt_texts.append(line)

func _show_enemy_taunt() -> void:
	var enemies: Array = []
	for u in _battle_units:
		var unit := u as BattleUnit
		if unit != null and not unit.is_dead and unit.is_enemy:
			enemies.append(unit)
	if enemies.is_empty():
		return
	var unit: BattleUnit = enemies[randi() % enemies.size()]
	var content: String = _taunt_texts[randi() % _taunt_texts.size()]
	var font: Font = load("res://asserts/fonts/ZCOOLKuaiLe.ttf")
	var font_size := 18
	var pad := Vector2(12, 8)
	var text_size := font.get_string_size(content, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var panel_w: float = text_size.x + pad.x * 2.0
	var panel_h: float = text_size.y + pad.y * 2.0
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.12, 0.22, 0.92)
	style.set_corner_radius_all(8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.2, 0.2, 1.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(panel_w, panel_h)
	panel.position = unit.root.position + Vector2(-panel_w * 0.5, -130)
	var lbl := Label.new()
	lbl.text = content
	lbl.position = pad
	lbl.size = Vector2(text_size.x, text_size.y)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = font_size
	ls.font_color = Color(1.0, 0.25, 0.2)
	lbl.label_settings = ls
	panel.add_child(lbl)
	panel.modulate.a = 0.0
	panel.z_index = 120
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_callback(panel.queue_free)

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
	# 隐身（30009）：剩余隐身回合数；> 0 期间 sprite 半透明且攻击伤害按 stealth_mult 计算
	var stealth_rounds: int   = 0
	var stealth_mult:   float = 1.0

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
		_play_hurt_sfx()
		var sf: SpriteFrames = sprite.sprite_frames
		if sf and sf.has_animation("hurt"):
			sprite.play("hurt")
			var s := sprite
			sprite.animation_finished.connect(func():
				_after_hurt(s, dying)
			, CONNECT_ONE_SHOT)
		else:
			_after_hurt(sprite, dying)

	func _play_hurt_sfx() -> void:
		var gender: String = rd.get("gender", "male")
		var path := "res://asserts/audio/hurt_man.ogg" if gender == "male" else "res://asserts/audio/hurt_woman.ogg"
		var stream := load(path) as AudioStream
		if not stream:
			return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -5.0
		sprite.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

	func _after_hurt(s: AnimatedSprite2D, dying: bool) -> void:
		if not is_instance_valid(s):
			return
		var sf: SpriteFrames = s.sprite_frames
		if dying:
			_play_die_sfx()
			if sf and sf.has_animation("dead"):
				s.play("dead")
		else:
			var back := "alert" if sf and sf.has_animation("alert") else "idle"
			if sf and sf.has_animation(back):
				s.play(back)

	func _play_die_sfx() -> void:
		var gender: String = rd.get("gender", "male")
		var path := "res://asserts/audio/die_man.ogg" if gender == "male" else "res://asserts/audio/die_woman.ogg"
		var stream := load(path) as AudioStream
		if not stream:
			return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -5.0
		sprite.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

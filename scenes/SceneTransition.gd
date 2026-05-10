extends CanvasLayer
# Autoload：跨场景的全屏黑色淡入淡出覆盖层。
# 用 SceneTransition.change_to(scene) 替代 change_scene_to_packed，
# 自动用黑屏掩盖切场景过程（Web 单线程下尤其有用）。

var _overlay: ColorRect


func _ready() -> void:
	layer = 1000  # 始终在最上层
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func change_to(scene: PackedScene, fade_in: float = 0.12, fade_out: float = 0.18) -> void:
	# 短淡入只为软过渡（Web 上 change_scene 之间会有一瞬清屏）。
	# 不再用长黑屏掩盖加载耗时 —— 让 LoadingScreen 尽快渲染，进度条自己来过渡。
	var t := create_tween()
	t.tween_property(_overlay, "color:a", 1.0, fade_in)
	await t.finished
	get_tree().change_scene_to_packed(scene)
	# 等一帧让新场景 _ready 完成 + 首次绘制
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_overlay, "color:a", 0.0, fade_out)

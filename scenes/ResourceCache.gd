extends Node
# Autoload：持有 LoadingScreen 预加载到的资源引用，
# 让后续场景里的 load() 命中 Godot 内部资源缓存而无需阻塞。

var _cache: Array[Resource] = []
var _waiting_main_ready: bool = false
var _main_ready_frames: int = 0

func add(res: Resource) -> void:
	if res != null and not _cache.has(res):
		_cache.append(res)

func size() -> int:
	return _cache.size()

# Web 平台：TitleScreen 切到 Main 后调用，等 Main 渲染 2 帧再通知 HTML 淡出
func wait_main_ready_and_notify_html() -> void:
	if not OS.has_feature("web") or _waiting_main_ready:
		return
	_waiting_main_ready = true
	_main_ready_frames = 0
	set_process(true)

func _process(_d: float) -> void:
	if not _waiting_main_ready:
		return
	_main_ready_frames += 1
	# 等 1 帧让 Main visible=true 真正渲染到屏幕，再通知 HTML 淡出
	if _main_ready_frames >= 2:
		_waiting_main_ready = false
		set_process(false)
		JavaScriptBridge.eval("window.__bce_main_ready = 1;", true)

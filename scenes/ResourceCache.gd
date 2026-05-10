extends Node
# Autoload：持有 LoadingScreen 预加载到的资源引用，
# 让后续场景里的 load() 命中 Godot 内部资源缓存而无需阻塞。

var _cache: Array[Resource] = []

func add(res: Resource) -> void:
	if res != null and not _cache.has(res):
		_cache.append(res)

func size() -> int:
	return _cache.size()

extends Node
# Autoload：启动时读 global_config.txt（key/value TSV），全局可访问。
# value 中的字面量 \n 解析为真换行符。

const PATH := "res://asserts/table/global_config.txt"

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	# 不要用 FileAccess.file_exists() —— 在 Web 导出里对 pack 内的 .txt 返回 false。
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		print("[GlobalConfig] not found: ", PATH)
		return
	var text := file.get_as_text()
	file.close()
	# 显式 codepoint 比较，不用字面量 BOM —— 源码里的 BOM 字面量会被导出过程吞掉。
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var raw := text.split("\n", false)
	if raw.size() < 2:
		return
	for i in range(1, raw.size()):  # skip header
		var line: String = (raw[i] as String).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("\t")
		if parts.size() < 2:
			continue
		var k: String = (parts[0] as String).strip_edges()
		var v: String = (parts[1] as String).strip_edges().replace("\\n", "\n")
		_data[k] = v


func get_str(key: String, default_value: String = "") -> String:
	return String(_data.get(key, default_value))


func get_int(key: String, default_value: int = 0) -> int:
	return int(_data.get(key, default_value))


func get_float(key: String, default_value: float = 0.0) -> float:
	return float(_data.get(key, default_value))

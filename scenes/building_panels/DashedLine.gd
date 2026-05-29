@tool
extends Control

@export var is_vertical: bool = true
@export var color: Color = Color(0.176, 0.118, 0.059, 0.55)
@export var line_width: float = 3.0
@export var dash: float = 6.0

func _draw() -> void:
	var s := size
	if is_vertical:
		draw_dashed_line(Vector2(s.x * 0.5, 0.0), Vector2(s.x * 0.5, s.y), color, line_width, dash)
	else:
		draw_dashed_line(Vector2(0.0, s.y * 0.5), Vector2(s.x, s.y * 0.5), color, line_width, dash)
